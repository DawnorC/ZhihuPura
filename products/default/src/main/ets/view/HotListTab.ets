import { FLOATING_BAR_CLEARANCE, MINI_TITLE_BAR_HEIGHT } from './NavigationChrome';
/**
 * Zhihu hot list tab, ported from HotListViewModel.kt.
 */
import { ZhihuApi, ZhihuFeedItem, ZhihuFeedPage, ZhihuHttpError } from '@ohos/common';
import { LoadingView, ErrorView, EmptyView } from './Widgets';
import { openFeedItem, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_CARD } from './NavHelper';

const RANK_COLORS: string[] = ['#F04142', '#F5A623', '#F7B500'];

@Component
export struct HotListTab {
  pathStack: NavPathStack = new NavPathStack();
  scroller: Scroller = new Scroller();
  @Prop titleInset: number = MINI_TITLE_BAR_HEIGHT;
  @StorageProp('floatingBottomBar') floatingBottomBar: boolean = false;
  @Prop @Watch('refreshFromTab') refreshRequest: number = 0;
  @State items: ZhihuFeedItem[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isRefreshing: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private refreshFromTab(): void {
    if (this.refreshRequest === 0 || this.isLoading || this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.load();
  }

  private load(): void {
    this.isLoading = this.items.length === 0;
    this.hasError = false;
    ZhihuApi.getInstance().fetchHotList(null)
      .then((page: ZhihuFeedPage): void => {
        this.items = page.items;
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

  build() {
    Column() {

      if (this.isLoading) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.hasError) {
        ErrorView({
          message: this.errorMessage,
          onRetry: (): void => {
            this.load();
          }
        })
          .layoutWeight(1)
      } else if (this.items.length === 0) {
        EmptyView({ message: '暂时没有内容' })
          .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            ForEach(this.items, (item: ZhihuFeedItem, index: number) => {
              ListItem() {
                Row({ space: 12 }) {
                  Text(String(index + 1))
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(index < RANK_COLORS.length ? RANK_COLORS[index] : APP_COLOR_SECONDARY)
                    .width(28)
                    .textAlign(TextAlign.Center)
                  Column({ space: 6 }) {
                    Text(item.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(APP_COLOR_TEXT)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .lineHeight(21)
                    Row({ space: 8 }) {
                      Text(item.details)
                        .fontSize(12)
                        .fontColor(APP_COLOR_SECONDARY)
                        .maxLines(1)
                    }
                    .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (item.thumbnailUrl.length > 0) {
                    Image(item.thumbnailUrl)
                      .width(60)
                      .height(60)
                      .borderRadius(6)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor('#EEEEEE')
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor('#FFFFFF')
                .onClick(() => {
                  openFeedItem(this.pathStack, item);
                })
              }
            }, (item: ZhihuFeedItem, index: number): string => item.id + '_' + index)
          }
          .width('100%')
          .height('100%')
          .clip(false)
          .cachedCount(3, true)
          .contentStartOffset(this.titleInset)
          .contentEndOffset(this.floatingBottomBar ? FLOATING_BAR_CLEARANCE : 0)
          .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
          .backgroundColor(APP_COLOR_CARD)
          .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 16 })
        }
        .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
        .onRefreshing(() => {
          this.load();
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
