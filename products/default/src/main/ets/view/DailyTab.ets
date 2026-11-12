/**
 * Zhihu Daily tab, ported from DailyViewModel.kt / ZhihuDailyClient.kt.
 * Sections grouped by date, loads older stories on reach end.
 */
import { ZhihuApi, ZhihuDailySection, ZhihuDailyStory, ZhihuHttpError } from '@ohos/common';
import { LoadingView, ErrorView, EmptyView } from './Widgets';
import { APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_BG, DailyStoryPageParam } from './NavHelper';

@Component
export struct DailyTab {
  pathStack: NavPathStack = new NavPathStack();
  @State sections: ZhihuDailySection[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State isRefreshing: boolean = false;
  @State loadingMore: boolean = false;

  aboutToAppear(): void {
    this.load();
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
    if (this.loadingMore || this.sections.length === 0) {
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
      Row() {
        Text('日报')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(APP_COLOR_TEXT)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')

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
          List() {
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
          .backgroundColor(APP_COLOR_BG)
          .onReachEnd(() => {
            this.loadMore();
          })
        }
        .onRefreshing(() => {
          this.load();
        })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLOR_BG)
  }

  @Builder
  sectionHeader(date: string) {
    Text(date.length > 0 ? '知乎日报 · ' + date : '知乎日报')
      .fontSize(13)
      .fontColor(APP_COLOR_BLUE)
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 8 })
      .backgroundColor(APP_COLOR_BG)
  }
}
