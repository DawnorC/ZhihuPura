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
import { openFeedItem, APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_BG } from './NavHelper';

@Component
export struct FeedListTab {
  pathStack: NavPathStack = new NavPathStack();
  fetcher: (url: string) => Promise<ZhihuFeedPage> =
    (url: string): Promise<ZhihuFeedPage> => ZhihuApi.getInstance().fetchRecommend(url.length > 0 ? url : null);
  headerTitle: string = '首页';
  showSearchEntry: boolean = false;
  loginRequired: boolean = false;
  emptyText: string = '暂时没有内容';
  @StorageProp('zhihuLoggedIn') loggedIn: boolean = false;
  @State items: ZhihuFeedItem[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isRefreshing: boolean = false;
  @State loadingMore: boolean = false;
  private nextUrl: string = '';
  private isEnd: boolean = false;

  aboutToAppear(): void {
    this.loadFirst(true);
  }

  private filterBlocked(page: ZhihuFeedPage): ZhihuFeedItem[] {
    const store = BlockStore.getInstance();
    const result: ZhihuFeedItem[] = [];
    const existing: string[] = [];
    for (let i = 0; i < this.items.length; i++) {
      existing.push(this.items[i].id + '#' + this.items[i].title);
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

  private loadFirst(showSpinner: boolean): void {
    if (showSpinner) {
      this.isLoading = true;
    }
    this.hasError = false;
    this.nextUrl = '';
    this.fetcher('')
      .then((page: ZhihuFeedPage): void => {
        this.items = this.filterBlocked(page);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
        this.isRefreshing = false;
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
        this.isRefreshing = false;
        if (this.items.length === 0) {
          this.hasError = true;
          this.errorMessage = error.message;
        }
      });
  }

  private loadMore(): void {
    if (this.loadingMore || this.isLoading || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.fetcher(this.nextUrl)
      .then((page: ZhihuFeedPage): void => {
        const fresh = this.filterBlocked(page);
        this.items = this.items.concat(fresh);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.loadingMore = false;
      })
      .catch((): void => {
        this.loadingMore = false;
      });
  }

  @Builder
  tabBarTop() {
    Row() {
      Text(this.headerTitle)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(APP_COLOR_TEXT)
      Blank()
      if (this.showSearchEntry) {
        Row({ space: 6 }) {
          Text('搜索')
            .fontSize(14)
            .fontColor(APP_COLOR_SECONDARY)
        }
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor('#F0F0F0')
        .borderRadius(15)
        .onClick(() => {
          this.pathStack.pushPathByName('search', '');
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
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
      this.tabBarTop()
      if (this.loginRequired && !this.loggedIn) {
        this.loginGate()
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 0 }) {
            if (this.items.length === 0 && !this.isLoading && !this.hasError) {
              ListItem() {
                EmptyView({ message: this.emptyText })
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
          .backgroundColor(APP_COLOR_BG)
          .onReachEnd(() => {
            this.loadMore();
          })
        }
        .onRefreshing(() => {
          this.loadFirst(false);
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLOR_BG)
  }
}
