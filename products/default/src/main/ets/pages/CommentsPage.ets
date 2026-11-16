import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { MINI_TITLE_BAR_HEIGHT, pageTitleBar } from '../view/NavigationChrome';
/**
 * Comments page, ported from CommentScreen / CommentScreenComponent (Kotlin),
 * with expandable child comments and comment liking.
 */
import {
  ZhihuApi,
  ZhihuComment,
  ZhihuCommentPage,
  ZhihuHttpError,
  ZhihuSession,
  formatCount,
  formatRelativeTime,
  stripHtml
} from '@ohos/common';
import { LoadingView, ErrorView, EmptyView } from '../view/Widgets';
import {
  CommentsPageParam,
  PeoplePageParam,
  showToast,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT,
  APP_COLOR_CARD
} from '../view/NavHelper';

const COMMENT_ORDER: SelectOption[] = [{ value: '按热度' }, { value: '按时间' }];

@Component
export struct CommentsPage {
  pathStack: NavPathStack = new NavPathStack();
  @StorageProp('statusBarHeightPx') private statusBarHeightPx: number = 0;
  private readonly scroller: Scroller = new Scroller();
  @State comments: ZhihuComment[] = [];
  @State childMap: Record<string, ZhihuComment[]> = {} as Record<string, ZhihuComment[]>;
  @State expandedMap: Record<string, boolean> = {} as Record<string, boolean>;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State loadingMore: boolean = false;
  @State orderIndex: number = 0;
  private kind: string = 'answers';
  private contentId: string = '';
  private nextUrl: string = '';
  private isEnd: boolean = false;
  private requestId: number = 0;

  private getTitleInset(): number {
    return MINI_TITLE_BAR_HEIGHT + this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  private load(): void {
    const requestId = ++this.requestId;
    this.isLoading = true;
    this.loadingMore = false;
    this.hasError = false;
    this.nextUrl = '';
    ZhihuApi.getInstance().fetchComments(this.kind, this.contentId, null, this.orderIndex === 1)
      .then((page: ZhihuCommentPage): void => {
        if (requestId !== this.requestId) {
          return;
        }
        this.comments = page.comments;
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
      })
      .catch((error: ZhihuHttpError): void => {
        if (requestId !== this.requestId) {
          return;
        }
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = error.message;
      });
  }

  private loadMore(): void {
    if (this.loadingMore || this.isLoading || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    const requestId = this.requestId;
    const previousUrl = this.nextUrl;
    this.loadingMore = true;
    ZhihuApi.getInstance().fetchComments(this.kind, this.contentId, previousUrl)
      .then((page: ZhihuCommentPage): void => {
        if (requestId !== this.requestId) {
          return;
        }
        this.comments = this.comments.concat(page.comments);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd || page.nextUrl === previousUrl;
        this.loadingMore = false;
      })
      .catch((): void => {
        if (requestId === this.requestId) {
          this.loadingMore = false;
        }
      });
  }

  private toggleExpand(comment: ZhihuComment): void {
    const expanded = this.expandedMap[comment.id] ?? false;
    if (expanded) {
      this.expandedMap[comment.id] = false;
      return;
    }
    if (comment.childCommentCount <= 0) {
      return;
    }
    const cached = this.childMap[comment.id];
    if (cached !== undefined) {
      this.expandedMap[comment.id] = true;
      return;
    }
    ZhihuApi.getInstance().fetchChildComments(comment.id, null)
      .then((page: ZhihuCommentPage): void => {
        this.childMap[comment.id] = page.comments;
        this.expandedMap[comment.id] = true;
      })
      .catch((): void => {
        showToast(this.getUIContext(), '回复加载失败');
      });
  }

  private likeComment(comment: ZhihuComment): void {
    const session = ZhihuSession.getInstance();
    if (!session.isLoggedIn()) {
      showToast(this.getUIContext(), '请先登录');
      return;
    }
    const nextLiked = !comment.liked;
    ZhihuApi.getInstance().likeComment(comment.id, nextLiked)
      .then((): void => {
        comment.liked = nextLiked;
        comment.likeCount = comment.likeCount + (nextLiked ? 1 : -1);
        this.comments = this.comments.slice();
      })
      .catch((): void => {
        showToast(this.getUIContext(), '操作失败');
      });
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.scroller }) {
        ListItem() {
          Row() {
            Select(COMMENT_ORDER)
              .selected(this.orderIndex)
              .value(COMMENT_ORDER[this.orderIndex].value)
              .onSelect((index: number) => {
                if (this.orderIndex !== index) {
                  this.orderIndex = index;
                  this.load();
                  this.scroller.scrollEdge(Edge.Top);
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ left: 16, right: 16, top: this.getTitleInset(), bottom: 8 })
        }

        if (this.isLoading) {
          ListItem() {
            LoadingView().height(220)
          }
        } else if (this.hasError) {
          ListItem() {
            ErrorView({
              message: this.errorMessage,
              onRetry: (): void => { this.load(); }
            }).height(220)
          }
        } else if (this.comments.length === 0) {
          ListItem() {
            EmptyView({ message: '还没有评论' }).height(220)
          }
        } else {
          ForEach(this.comments, (comment: ZhihuComment, index: number) => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  if (comment.authorAvatar.length > 0) {
                    Image(comment.authorAvatar)
                      .width(24)
                      .height(24)
                      .borderRadius(12)
                      .backgroundColor('#EEEEEE')
                  } else {
                    Circle({ width: 24, height: 24 })
                      .fill('#DDDDDD')
                  }
                  Text(comment.authorName.length > 0 ? comment.authorName : '匿名用户')
                    .fontSize(14)
                    .fontColor(comment.isAuthor ? APP_COLOR_BLUE : APP_COLOR_TEXT)
                    .maxLines(1)
                    .onClick(() => {
                      if (comment.authorToken.length > 0) {
                        const param: PeoplePageParam = { urlToken: comment.authorToken };
                        this.pathStack.pushPathByName('people', param);
                      }
                    })
                  if (comment.isAuthor) {
                    Text('作者')
                      .fontSize(10)
                      .fontColor(APP_COLOR_BLUE)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                      .borderRadius(3)
                      .border({ width: 0.5, color: APP_COLOR_BLUE })
                  }
                  Blank()
                  Text(formatRelativeTime(comment.createdTime))
                    .fontSize(11)
                    .fontColor(APP_COLOR_SECONDARY)
                }
                .width('100%')

                Text(stripHtml(comment.content))
                  .fontSize(15)
                  .fontColor(APP_COLOR_TEXT)
                  .lineHeight(22)
                  .width('100%')

                Row({ space: 16 }) {
                  Text(comment.liked ? '已赞 ' + formatCount(comment.likeCount) :
                    '赞 ' + formatCount(comment.likeCount))
                    .fontSize(12)
                    .fontColor(comment.liked ? APP_COLOR_BLUE : APP_COLOR_SECONDARY)
                    .onClick(() => {
                      this.likeComment(comment);
                    })
                  if (comment.childCommentCount > 0) {
                    Text((this.expandedMap[comment.id] ?? false) ? '收起回复' :
                      '查看 ' + comment.childCommentCount + ' 条回复')
                      .fontSize(12)
                      .fontColor(APP_COLOR_SECONDARY)
                      .onClick(() => {
                        this.toggleExpand(comment);
                      })
                  }
                }
                .width('100%')

                if (this.expandedMap[comment.id] ?? false) {
                  Column({ space: 8 }) {
                    ForEach(this.childMap[comment.id] ?? [], (child: ZhihuComment, childIndex: number) => {
                      Column({ space: 4 }) {
                        Row({ space: 6 }) {
                          Text(child.authorName.length > 0 ? child.authorName : '匿名用户')
                            .fontSize(12)
                            .fontColor(APP_COLOR_TEXT)
                          if (child.replyToName.length > 0) {
                            Text('回复 ' + child.replyToName)
                              .fontSize(12)
                              .fontColor(APP_COLOR_SECONDARY)
                          }
                          Blank()
                          Text(formatRelativeTime(child.createdTime))
                            .fontSize(10)
                            .fontColor(APP_COLOR_SECONDARY)
                        }
                        .width('100%')
                        Text(stripHtml(child.content))
                          .fontSize(13)
                          .fontColor('#333333')
                          .lineHeight(19)
                          .width('100%')
                      }
                      .width('100%')
                      .alignItems(HorizontalAlign.Start)
                      .padding(8)
                      .backgroundColor('#F7F7F7')
                      .borderRadius(6)
                    }, (child: ZhihuComment, childIndex: number): string => comment.id + '_' + child.id)
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor(APP_COLOR_CARD)
            }
          }, (comment: ZhihuComment, index: number): string => comment.id + '_' + index)
          if (this.loadingMore) {
            ListItem() {
              LoadingView({ label: '加载更多…' })
            }
          }
        }
      }
      .width('100%')
      .height(LayoutPolicy.matchParent)
      .clip(false)
      .cachedCount(3, true)
      .backgroundColor(APP_COLOR_CARD)
      .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 16, endMargin: 16 })
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .onReachEnd(() => { this.loadMore(); })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar('评论', this.getTitleInset()))
    .bindToScrollable([this.scroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(APP_COLOR_CARD)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as CommentsPageParam;
      this.kind = param.kind;
      this.contentId = param.id;
      if (this.kind !== 'answers' && this.kind !== 'articles' && this.kind !== 'pins' && this.kind !== 'questions') {
        this.kind = 'answers';
      }
      this.load();
    })
  }
}

@Builder
export function CommentsBuilder() {
  CommentsPage()
}
