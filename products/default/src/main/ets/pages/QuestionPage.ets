/**
 * Question detail page, ported from QuestionScreen.kt: question header + paged answer list.
 */
import {
  HistoryStore,
  ZhihuApi,
  ZhihuFeedItem,
  ZhihuFeedPage,
  ZhihuHttpError,
  ZhihuQuestion,
  formatCount,
  stripHtml
} from '@ohos/common';
import { FeedCard } from '../view/FeedCard';
import { LoadingView, ErrorView, EmptyView } from '../view/Widgets';
import {
  QuestionPageParam,
  openFeedItem,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT,
  APP_COLOR_BG
} from '../view/NavHelper';

@Component
export struct QuestionPage {
  pathStack: NavPathStack = new NavPathStack();
  @State question: ZhihuQuestion | null = null;
  @State items: ZhihuFeedItem[] = [];
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State sortByTime: boolean = false;
  @State loadingMore: boolean = false;
  private questionId: string = '';
  private nextUrl: string = '';
  private isEnd: boolean = false;

  private loadQuestion(): void {
    ZhihuApi.getInstance().fetchQuestion(this.questionId)
      .then((question: ZhihuQuestion): void => {
        this.question = question;
        HistoryStore.getInstance().record(getContext(this), 'question', this.questionId, question.title)
          .catch((): void => {});
      })
      .catch((): void => {
        // question header is best-effort; the answer list still loads
      });
  }

  private loadAnswers(): void {
    this.isLoading = this.items.length === 0;
    this.hasError = false;
    this.nextUrl = '';
    const order = this.sortByTime ? 'created' : 'default';
    ZhihuApi.getInstance().fetchQuestionAnswers(this.questionId, null, order)
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
    ZhihuApi.getInstance().fetchQuestionAnswers(this.questionId, this.nextUrl, '')
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
        if (this.isLoading) {
          LoadingView()
            .layoutWeight(1)
        } else if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.loadAnswers();
            }
          })
            .layoutWeight(1)
        } else {
          List({ space: 0 }) {
            if (this.question !== null) {
              ListItem() {
                Column({ space: 8 }) {
                  Text(this.question.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(APP_COLOR_TEXT)
                    .lineHeight(26)
                  if (this.question.detailHtml.length > 0) {
                    Text(stripHtml(this.question.detailHtml))
                      .fontSize(14)
                      .fontColor('#444444')
                      .lineHeight(21)
                  }
                  Text(formatCount(this.question.followerCount) + ' 人关注 · ' +
                    formatCount(this.question.answerCount) + ' 个回答')
                    .fontSize(12)
                    .fontColor(APP_COLOR_SECONDARY)
                  Row({ space: 8 }) {
                    this.sortChip('默认排序', false)
                    this.sortChip('按时间排序', true)
                  }
                  .margin({ top: 4, bottom: 4 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(16)
                .backgroundColor('#FFFFFF')
              }
            }
            if (this.items.length === 0 && !this.isLoading) {
              ListItem() {
                EmptyView({ message: '还没有回答' })
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
    .title('问题')
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as QuestionPageParam;
      this.questionId = param.id;
      this.loadQuestion();
      this.loadAnswers();
    })
  }

  @Builder
  sortChip(label: string, isTime: boolean) {
    Text(label)
      .fontSize(13)
      .fontColor(this.sortByTime === isTime ? '#FFFFFF' : APP_COLOR_TEXT)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.sortByTime === isTime ? APP_COLOR_BLUE : '#F0F0F0')
      .borderRadius(15)
      .onClick(() => {
        if (this.sortByTime !== isTime) {
          this.sortByTime = isTime;
          this.loadAnswers();
        }
      })
  }
}

@Builder
export function QuestionBuilder() {
  QuestionPage()
}
