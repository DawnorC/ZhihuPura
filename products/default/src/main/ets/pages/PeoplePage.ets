import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { pageTitleBar } from '../view/NavigationChrome';
/**
 * People profile page, ported from PeopleScreen.kt: profile header + answers/articles tabs.
 */
import {
  ZhihuApi,
  ZhihuPerson,
  ZhihuFeedItem,
  ZhihuFeedPage,
  ZhihuHttpError,
  ZhihuSession,
  formatCount
} from '@ohos/common';
import { FeedCard } from '../view/FeedCard';
import { LoadingView, ErrorView, EmptyView } from '../view/Widgets';
import {
  PeoplePageParam,
  openFeedItem,
  showToast,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT,
  APP_COLOR_BG
} from '../view/NavHelper';

@Component
export struct PeoplePage {
  pathStack: NavPathStack = new NavPathStack();
  @State person: ZhihuPerson | null = null;
  @State items: ZhihuFeedItem[] = [];
  @State showArticles: boolean = false;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isFollowing: boolean = false;
  @State loadingMore: boolean = false;
  private urlToken: string = '';
  private nextUrl: string = '';
  private isEnd: boolean = false;

  private loadProfile(): void {
    ZhihuApi.getInstance().fetchPeople(this.urlToken)
      .then((person: ZhihuPerson): void => {
        this.person = person;
        this.isFollowing = person.isFollowing;
      })
      .catch((): void => {
        // profile header is best-effort
      });
  }

  private loadContent(): void {
    this.isLoading = this.items.length === 0;
    this.hasError = false;
    this.nextUrl = '';
    let task: Promise<ZhihuFeedPage>;
    if (this.showArticles) {
      task = ZhihuApi.getInstance().fetchPeopleArticles(this.urlToken, null);
    } else {
      task = ZhihuApi.getInstance().fetchPeopleAnswers(this.urlToken, null);
    }
    task
      .then((page: ZhihuFeedPage): void => {
        this.items = page.items;
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
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
    let task: Promise<ZhihuFeedPage>;
    if (this.showArticles) {
      task = ZhihuApi.getInstance().fetchPeopleArticles(this.urlToken, this.nextUrl);
    } else {
      task = ZhihuApi.getInstance().fetchPeopleAnswers(this.urlToken, this.nextUrl);
    }
    task
      .then((page: ZhihuFeedPage): void => {
        this.items = this.items.concat(page.items);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.loadingMore = false;
      })
      .catch((): void => {
        this.loadingMore = false;
      });
  }

  private toggleFollow(): void {
    const session = ZhihuSession.getInstance();
    if (!session.isLoggedIn()) {
      showToast(this.getUIContext(), '请先登录');
      return;
    }
    const next = !this.isFollowing;
    ZhihuApi.getInstance().followPeople(this.urlToken, next)
      .then((): void => {
        this.isFollowing = next;
        showToast(this.getUIContext(), next ? '已关注' : '已取消关注');
      })
      .catch((): void => {
        showToast(this.getUIContext(), '操作失败');
      });
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.isLoading) {
          LoadingView()
            .layoutWeight(1)
        } else if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.loadContent();
            }
          })
            .layoutWeight(1)
        } else {
          List({ space: 0 }) {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 14 }) {
                  if (this.person !== null && this.person.avatarUrl.length > 0) {
                    Image(this.person.avatarUrl)
                      .width(64)
                      .height(64)
                      .borderRadius(32)
                      .backgroundColor('#EEEEEE')
                  } else {
                    Circle({ width: 64, height: 64 })
                      .fill('#DDDDDD')
                  }
                  Column({ space: 4 }) {
                    Text(this.person !== null && this.person.name.length > 0 ? this.person.name : this.urlToken)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(APP_COLOR_TEXT)
                    if (this.person !== null && this.person.headline.length > 0) {
                      Text(this.person.headline)
                        .fontSize(13)
                        .fontColor(APP_COLOR_SECONDARY)
                        .maxLines(1)
                    }
                    if (this.person !== null) {
                      Text(formatCount(this.person.followerCount) + ' 关注者 · ' +
                        formatCount(this.person.answerCount) + ' 回答 · ' +
                        formatCount(this.person.articlesCount) + ' 文章')
                        .fontSize(12)
                        .fontColor(APP_COLOR_SECONDARY)
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Button(this.isFollowing ? '已关注' : '+ 关注')
                    .fontSize(13)
                    .height(32)
                    .backgroundColor(this.isFollowing ? '#F0F0F0' : APP_COLOR_BLUE)
                    .fontColor(this.isFollowing ? APP_COLOR_TEXT : '#FFFFFF')
                    .onClick(() => {
                      this.toggleFollow();
                    })
                }
                .width('100%')

                Row({ space: 8 }) {
                  Text('回答')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.showArticles ? APP_COLOR_SECONDARY : APP_COLOR_BLUE)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      if (this.showArticles) {
                        this.showArticles = false;
                        this.loadContent();
                      }
                    })
                  Text('文章')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.showArticles ? APP_COLOR_BLUE : APP_COLOR_SECONDARY)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      if (!this.showArticles) {
                        this.showArticles = true;
                        this.loadContent();
                      }
                    })
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor('#FFFFFF')
            }

            if (this.items.length === 0 && !this.isLoading) {
              ListItem() {
                EmptyView({ message: this.showArticles ? '还没有发布文章' : '还没有回答' })
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
            }, (item: ZhihuFeedItem, index: number): string => item.id + '_' + index)
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
      }
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar('个人主页'))
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as PeoplePageParam;
      this.urlToken = param.urlToken;
      this.loadProfile();
      this.loadContent();
    })
  }
}

@Builder
export function PeopleBuilder() {
  PeoplePage()
}
