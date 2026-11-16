import { FLOATING_BAR_CLEARANCE, MINI_TITLE_BAR_HEIGHT } from './NavigationChrome';
/**
 * Zhihu Daily tab, ported from DailyViewModel.kt / ZhihuDailyClient.kt.
 * Sections grouped by date, loads older stories on reach end.
 */
import { ZhihuApi, ZhihuDailySection, ZhihuDailyStory, ZhihuHttpError } from '@ohos/common';
import { LoadingView, ErrorView, EmptyView } from './Widgets';
import { APP_COLOR_TEXT, APP_COLOR_CARD, APP_COLOR_DIVIDER, DailyStoryPageParam } from './NavHelper';

@Component
export struct DailyTab {
  pathStack: NavPathStack = new NavPathStack();
  scroller: Scroller = new Scroller();
  @Prop titleInset: number = MINI_TITLE_BAR_HEIGHT;
  @StorageProp('floatingBottomBar') floatingBottomBar: boolean = false;
  @Prop @Watch('refreshFromTab') refreshRequest: number = 0;
  @State sections: ZhihuDailySection[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isRefreshing: boolean = false;
  @State loadingMore: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private refreshFromTab(): void {
    if (this.loadingMore || this.refreshRequest === 0 || this.isLoading || this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.load();
  }

  private totalStories(): number {
    let total = 0;
    for (let i = 0; i < this.sections.length; i++) {
      total += this.sections[i].stories.length;
    }
    return total;
  }

  private load(): void {
    this.isLoading = this.sections.length === 0;
    this.hasError = false;
    ZhihuApi.getInstance().fetchDailyLatest()
      .then((section: ZhihuDailySection): void => {
        if (section.stories.length > 0) {
          this.sections = [section];
        } else {
          this.sections = [];
        }
        this.isLoading = false;
        this.isRefreshing = false;
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
        this.isRefreshing = false;
        if (this.sections.length === 0) {
          this.hasError = true;
          this.errorMessage = error.message;
        }
      });
  }

  private loadMore(): void {
    if (this.loadingMore || this.isRefreshing || this.sections.length === 0) {
      return;
    }
    const lastDate = this.sections[this.sections.length - 1].date;
    if (lastDate.length === 0) {
      return;
    }
    this.loadingMore = true;
    ZhihuApi.getInstance().fetchDailyBefore(lastDate)
      .then((section: ZhihuDailySection): void => {
        if (section.stories.length > 0) {
          this.sections = this.sections.concat([section]);
        }
        this.loadingMore = false;
      })
      .catch((): void => {
        this.loadingMore = false;
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
      } else if (this.sections.length === 0) {
        EmptyView({ message: '暂时没有内容' })
          .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ scroller: this.scroller }) {
            ForEach(this.sections, (section: ZhihuDailySection, sectionIndex: number) => {
              ListItemGroup({ header: this.sectionHeader(section.date) }) {
                ForEach(section.stories, (story: ZhihuDailyStory, storyIndex: number) => {
                  ListItem() {
                    Row({ space: 12 }) {
                      Text(story.title)
                        .fontSize(15)
                        .fontColor(APP_COLOR_TEXT)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .lineHeight(21)
                        .layoutWeight(1)
                      if (story.imageUrl.length > 0) {
                        Image(story.imageUrl)
                          .width(72)
                          .height(56)
                          .borderRadius(6)
                          .objectFit(ImageFit.Cover)
                          .backgroundColor('#EEEEEE')
                      }
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .padding({ left: 16, right: 16, top: 11, bottom: 11 })
                    .backgroundColor('#FFFFFF')
                    .onClick(() => {
                      const param: DailyStoryPageParam = { id: story.id };
                      this.pathStack.pushPathByName('dailystory', param);
                    })
                  }
                }, (story: ZhihuDailyStory, storyIndex: number): string => section.date + '_' + story.id)
              }
            }, (section: ZhihuDailySection, sectionIndex: number): string => section.date + '_' + sectionIndex)
            if (this.loadingMore) {
              ListItem() {
                LoadingView({ label: '加载更多…' })
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
            if (this.totalStories() > 0 && end >= this.totalStories() - 8) {
              this.loadMore();
            }
          })
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

  private formatSectionDate(date: string): string {
    const parts = /^(\d{4})(\d{2})(\d{2})$/.exec(date);
    return parts ? parts[1] + '年' + Number(parts[2]) + '月' + Number(parts[3]) + '日' : date;
  }

  @Builder
  sectionHeader(date: string) {
    if (date.length > 0) {
      Row({ space: 12 }) {
        Text(this.formatSectionDate(date))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#62676F')
        Divider()
          .strokeWidth(1)
          .color(APP_COLOR_DIVIDER)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .backgroundColor(APP_COLOR_CARD)
    }
  }
}
