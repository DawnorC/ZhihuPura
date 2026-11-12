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
  APP_COLOR_BG
} from '../view/NavHelper';

@Component
export struct CommentsPage {
  pathStack: NavPathStack = new NavPathStack();
  @State comments: ZhihuComment[] = [];
  @State childMap: Record<string, ZhihuComment[]> = {} as Record<string, ZhihuComment[]>;
  @State expandedMap: Record<string, boolean> = {} as Record<string, boolean>;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State loadingMore: boolean = false;
  private kind: string = 'answers';
  private contentId: string = '';
  private nextUrl: string = '';
  private isEnd: boolean = false;

  private load(): void {
    this.isLoading = this.comments.length === 0;
    this.hasError = false;
    this.nextUrl = '';
    ZhihuApi.getInstance().fetchComments(this.kind, this.contentId, null)
      .then((page: ZhihuCommentPage): void => {
        this.comments = page.comments;
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.isLoading = false;
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
        if (this.comments.length === 0) {
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
    ZhihuApi.getInstance().fetchComments(this.kind, this.contentId, this.nextUrl)
      .then((page: ZhihuCommentPage): void => {
        this.comments = this.comments.concat(page.comments);
        this.nextUrl = page.nextUrl;
        this.isEnd = page.isEnd;
        this.loadingMore = false;
      })
      .catch((): void => {
        this.loadingMore = false;
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
    NavDestination() {
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
        } else if (this.comments.length === 0) {
          EmptyView({ message: '还没有评论' })
            .layoutWeight(1)
        } else {
          List() {
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
                .backgroundColor('#FFFFFF')
              }
            }, (comment: ZhihuComment, index: number): string => comment.id + '_' + index)
            if (this.loadingMore) {
              ListItem() {
                LoadingView({ label: '加载更多…' })
              }
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor(APP_COLOR_BG)
          .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 16, endMargin: 16 })
          .onReachEnd(() => {
            this.loadMore();
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('评论')
    .backgroundColor(APP_COLOR_BG)
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
