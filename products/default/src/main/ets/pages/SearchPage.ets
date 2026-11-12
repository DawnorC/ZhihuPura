/**
 * Search page, ported from SearchScreen.kt: TextInput + search_v3 results
 * (content results render as FeedCard, people results as user rows).
 */
import {
  ZhihuApi,
  ZhihuContentType,
  ZhihuFeedItem,
  ZhihuFeedPage,
  ZhihuHttpError
} from '@ohos/common';
import { FeedCard } from '../view/FeedCard';
import { LoadingView, ErrorView, EmptyView } from '../view/Widgets';
import {
  PeoplePageParam,
  openFeedItem,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT,
  APP_COLOR_BG
} from '../view/NavHelper';

@Component
export struct SearchPage {
  pathStack: NavPathStack = new NavPathStack();
  @State query: string = '';
  @State items: ZhihuFeedItem[] = [];
  @State hasSearched: boolean = false;
  @State isLoading: boolean = false;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State loadingMore: boolean = false;
  private nextUrl: string = '';
  private isEnd: boolean = false;

  private doSearch(): void {
    const keyword = this.query.trim();
    if (keyword.length === 0) {
      return;
    }
    this.isLoading = true;
    this.hasError = false;
    this.hasSearched = true;
    this.nextUrl = '';
    ZhihuApi.getInstance().search(keyword, null)
      .then((page: ZhihuFeedPage): void => {
        this.items = page.items;
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = error.message;
      });
  }

  private loadMore(): void {
    if (this.loadingMore || this.isLoading || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    this.loadingMore = true;
    ZhihuApi.getInstance().search(this.query.trim(), this.nextUrl)
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

  build() {
    NavDestination() {
      Column() {
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索知乎内容', text: this.query })
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .onChange((value: string) => {
              this.query = value;
            })
            .onSubmit(() => {
              this.doSearch();
            })
          Button('搜索')
            .fontSize(14)
            .height(36)
            .backgroundColor(APP_COLOR_BLUE)
            .onClick(() => {
              this.doSearch();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.isLoading) {
          LoadingView()
            .layoutWeight(1)
        } else if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.doSearch();
            }
          })
            .layoutWeight(1)
        } else if (!this.hasSearched) {
          EmptyView({ message: '输入关键词开始搜索' })
            .layoutWeight(1)
        } else if (this.items.length === 0) {
          EmptyView({ message: '没有找到相关内容' })
            .layoutWeight(1)
        } else {
          List() {
            ForEach(this.items, (item: ZhihuFeedItem, index: number) => {
              ListItem() {
                Column() {
                  if (item.contentType === ZhihuContentType.People) {
                    Row({ space: 12 }) {
                      if (item.authorAvatar.length > 0) {
                        Image(item.authorAvatar)
                          .width(44)
                          .height(44)
                          .borderRadius(22)
                          .backgroundColor('#EEEEEE')
                      } else {
                        Circle({ width: 44, height: 44 })
                          .fill('#DDDDDD')
                      }
                      Column({ space: 4 }) {
                        Text(item.title)
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(APP_COLOR_TEXT)
                          .maxLines(1)
                        if (item.summary.length > 0) {
                          Text(item.summary)
                            .fontSize(13)
                            .fontColor(APP_COLOR_SECONDARY)
                            .maxLines(1)
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      Text('用户')
                        .fontSize(11)
                        .fontColor(APP_COLOR_BLUE)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                    .backgroundColor('#FFFFFF')
                    .onClick(() => {
                      const param: PeoplePageParam = { urlToken: item.authorToken };
                      this.pathStack.pushPathByName('people', param);
                    })
                  } else {
                    FeedCard({
                      item: item,
                      onOpen: (opened: ZhihuFeedItem): void => {
                        openFeedItem(this.pathStack, opened);
                      }
                    })
                  }
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
      .backgroundColor(APP_COLOR_BG)
    }
    .title('搜索')
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Builder
export function SearchBuilder() {
  SearchPage()
}
