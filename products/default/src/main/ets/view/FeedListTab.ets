import { FLOATING_BAR_CLEARANCE, MINI_TITLE_BAR_HEIGHT } from './NavigationChrome';
/**
 * Generic paged feed list tab, ported from BaseFeedViewModel + HomeFeedViewModel (Kotlin).
 * Handles: paging, pull-to-refresh, infinite scroll, blocklist filtering, login gate.
 */
import {
  ZhihuApi,
  ZhihuFeedItem,
  ZhihuFeedPage,
  ZhihuHttpError,
  BlockStore
} from '@ohos/common';
import { FeedCard } from './FeedCard';
import { LoadingView, ErrorView, EmptyView } from './Widgets';
import { openFeedItem, showToast, APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_CARD } from './NavHelper';

@Component
export struct FeedListTab {
  pathStack: NavPathStack = new NavPathStack();
  scroller: Scroller = new Scroller();
  @Prop titleInset: number = MINI_TITLE_BAR_HEIGHT;
  @Prop @Watch('accountContextChanged') sessionReady: boolean = false;
  @StorageProp('floatingBottomBar') floatingBottomBar: boolean = false;
  @Prop @Watch('refreshFromTab') refreshRequest: number = 0;
  fetcher: (url: string) => Promise<ZhihuFeedPage> =
    (url: string): Promise<ZhihuFeedPage> => ZhihuApi.getInstance().fetchRecommend(url.length > 0 ? url : null);
  loginRequired: boolean = false;
  emptyText: string = '暂时没有内容';
  @StorageProp('zhihuLoggedIn') @Watch('accountContextChanged') loggedIn: boolean = false;
  @State items: ZhihuFeedItem[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isRefreshing: boolean = false;
  @State loadingMore: boolean = false;
  private nextUrl: string = '';
  private isEnd: boolean = false;
  private active: boolean = false;
  private loadingFirst: boolean = false;
  private requestGeneration: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.accountContextChanged();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.requestGeneration++;
  }

  private accountContextChanged(): void {
    if (!this.active || !this.sessionReady) {
      return;
    }
    this.requestGeneration++;
    this.items = [];
    this.nextUrl = '';
    this.isEnd = false;
    this.loadingFirst = false;
    this.loadingMore = false;
    this.isRefreshing = false;
    this.hasError = false;
    this.loadFirst(true);
  }

  private canLoad(): boolean {
    return this.active && this.sessionReady && (!this.loginRequired || this.loggedIn);
  }

  private filterBlocked(page: ZhihuFeedPage, append: boolean): ZhihuFeedItem[] {
    const store = BlockStore.getInstance();
    const result: ZhihuFeedItem[] = [];
    const existing: string[] = [];
    if (append) {
      for (const item of this.items) {
        existing.push(item.id + '#' + item.title);
      }
    }
    for (let i = 0; i < page.items.length; i++) {
      const item = page.items[i];
      if (store.isBlocked(item.title, item.summary)) {
        continue;
      }
      const key = item.id + '#' + item.title;
      if (existing.indexOf(key) >= 0) {
        continue;
      }
      existing.push(key);
      result.push(item);
    }
    return result;
  }

  private refreshFromTab(): void {
    if (!this.canLoad() || this.loadingFirst || this.refreshRequest === 0 || this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.loadFirst(false);
  }

  private loadErrorMessage(error: Error): string {
    if (error instanceof ZhihuHttpError) {
      if (error.status === 401) {
        return this.loggedIn ? '登录状态已失效，请重新登录知乎' : '请登录知乎后重试';
      }
      if (error.status === 403) {
        return '知乎暂时限制了此次内容请求';
      }
      if (error.status === 429) {
        return '请求较频繁，请稍后重试';
      }
      if (error.status === -1) {
        return '连接知乎失败，请检查网络后重试';
      }
    }
    return '暂时无法获取内容，请稍后重试';
  }

  private async loadFirst(showSpinner: boolean): Promise<void> {
    if (!this.canLoad() || this.loadingFirst) {
      return;
    }
    const generation = ++this.requestGeneration;
    this.loadingFirst = true;
    this.loadingMore = false;
    this.isLoading = showSpinner;
    this.hasError = false;
    try {
      const page = await this.fetcher('');
      if (this.requestGeneration !== generation) {
        return;
      }
      this.items = this.filterBlocked(page, false);
      this.nextUrl = page.nextUrl;
      this.isEnd = page.isEnd;
    } catch (error) {
      if (this.requestGeneration === generation) {
        const message = this.loadErrorMessage(error as Error);
        if (this.items.length === 0) {
          this.hasError = true;
          this.errorMessage = message;
        } else {
          showToast(this.getUIContext(), message);
        }
      }
    } finally {
      if (this.requestGeneration === generation) {
        this.loadingFirst = false;
        this.isLoading = false;
        this.isRefreshing = false;
      }
    }
  }

  private loadMore(): void {
    if (!this.canLoad() || this.loadingMore || this.loadingFirst || this.isRefreshing ||
      this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    const generation = this.requestGeneration;
    const requestUrl = this.nextUrl;
    this.loadingMore = true;
    this.fetcher(requestUrl)
      .then((page: ZhihuFeedPage): void => {
        if (this.requestGeneration !== generation) {
          return;
        }
        const fresh = this.filterBlocked(page, true);
        this.items = this.items.concat(fresh);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd || page.nextUrl === requestUrl;
      })
      .catch((): void => {
        // Retain the current page and retry its next URL on the next scroll.
      })
      .finally((): void => {
        if (this.requestGeneration === generation) {
          this.loadingMore = false;
        }
      });
  }

  @Builder
  loginGate() {
    Column({ space: 16 }) {
      Text('登录后即可查看')
        .fontSize(16)
        .fontColor(APP_COLOR_TEXT)
      Text('该内容需要登录知乎账号后查看')
        .fontSize(13)
        .fontColor(APP_COLOR_SECONDARY)
      Button('登录')
        .fontSize(15)
        .height(40)
        .width(120)
        .backgroundColor(APP_COLOR_BLUE)
        .onClick(() => {
          this.pathStack.pushPathByName('login', '');
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.sessionReady && this.loginRequired && !this.loggedIn) {
        this.loginGate()
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 0, scroller: this.scroller }) {
            if (this.items.length === 0) {
              ListItem() {
                if (this.isLoading) {
                  LoadingView()
                } else if (this.hasError) {
                  ErrorView({ message: this.errorMessage, onRetry: (): void => { this.loadFirst(true); } })
                } else {
                  EmptyView({ message: this.emptyText })
                }
              }
            }
            ForEach(this.items, (item: ZhihuFeedItem, index: number) => {
              ListItem() {
                Column() {
                  FeedCard({
                    item: item,
                    onOpen: (opened: ZhihuFeedItem): void => {
                      openFeedItem(this.pathStack, opened);
                    }
                  })
                  Divider()
                    .color('#F0F0F0')
                    .strokeWidth(1)
                    .margin({ left: 16 })
                }
              }
            }, (item: ZhihuFeedItem, index: number): string => item.id + '_' + item.contentType + '_' + index)
            if (this.loadingMore) {
              ListItem() {
                LoadingView({ label: '加载更多…' })
              }
            } else if (this.isEnd && this.items.length > 0) {
              ListItem() {
                Text('— 已经到底啦 —')
                  .fontSize(12)
                  .fontColor(APP_COLOR_SECONDARY)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(12)
              }
            }
          }
          .width('100%')
          .height('100%')
          .clip(false)
          .cachedCount(3, true)
          .contentStartOffset(this.titleInset)
          .contentEndOffset(this.floatingBottomBar ? FLOATING_BAR_CLEARANCE : 0)
          .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
          .backgroundColor(APP_COLOR_CARD)
          .onReachEnd(() => {
            this.loadMore();
          })
          .onScrollIndex((start: number, end: number) => {
            // Prefetch ahead so the list rarely reaches its end, where the
            // HDS title bar forces itself visible.
            if (this.items.length > 0 && end >= this.items.length - 4) {
              this.loadMore();
            }
          })
        }
        .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
        .onRefreshing(() => {
          this.loadFirst(false);
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
    .backgroundColor(APP_COLOR_CARD)
  }
}
