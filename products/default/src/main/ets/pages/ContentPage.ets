/**
 * Content page (answer / article / pin reader), ported from ArticleScreen / AnswerPage (Kotlin).
 * Content HTML rendered in an embedded Web component, with vote / comment / share action bar.
 */
import { webview } from '@kit.ArkWeb';
import {
  HistoryStore,
  ZhihuApi,
  ZhihuContent,
  ZhihuHttpError,
  ZhihuSession,
  formatRelativeTime
} from '@ohos/common';
import { LoadingView, ErrorView } from '../view/Widgets';
import {
  ContentPageParam,
  CommentsPageParam,
  PeoplePageParam,
  showToast,
  copyToClipboard,
  openInBrowser,
  APP_COLOR_BLUE,
  APP_COLOR_SECONDARY,
  APP_COLOR_TEXT
} from '../view/NavHelper';

@Component
export struct ContentPage {
  pathStack: NavPathStack = new NavPathStack();
  @State content: ZhihuContent | null = null;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @State voted: boolean = false;
  @State voteCount: number = 0;
  @State pageTitle: string = '';
  @State contentReady: boolean = false;
  private kind: string = 'answer';
  private contentId: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();
  private documentHtml: string = '';

  private buildDocument(content: ZhihuContent): string {
    const css: string = 'body{margin:0;padding:16px;font-size:16px;line-height:1.75;color:#1A1A1A;' +
      'word-break:break-word;background:#FFFFFF;font-family:"HarmonyOS Sans SC","PingFang SC","Microsoft YaHei",sans-serif;}' +
      'img{max-width:100%;height:auto;border-radius:4px;}' +
      'a{color:#0066FF;text-decoration:none;}' +
      'p{margin:0 0 12px 0;}' +
      'blockquote{margin:12px 0;padding:8px 12px;border-left:3px solid #E8E8E8;background:#F8F8F8;color:#555555;}' +
      'h1,h2,h3{margin:16px 0 8px 0;font-weight:bold;}' +
      'figure{margin:0 0 12px 0;}' +
      'code,pre{background:#F6F6F6;border-radius:4px;}' +
      'pre{padding:8px;overflow-x:auto;}' +
      'hr{border:none;border-top:1px solid #F0F0F0;margin:16px 0;}';
    const script: string = '(function(){var imgs=document.querySelectorAll("img");' +
      'for(var i=0;i<imgs.length;i++){var im=imgs[i];var s=im.getAttribute("data-actualsrc")||' +
      'im.getAttribute("data-original");if(s){im.setAttribute("src",s);}im.removeAttribute("srcset");}})();';
    return '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=3">' +
      '<style>' + css + '</style></head><body>' + content.contentHtml +
      '<script>' + script + '</script></body></html>';
  }

  private load(): void {
    this.isLoading = true;
    this.hasError = false;
    this.contentReady = false;
    const api = ZhihuApi.getInstance();
    let task: Promise<ZhihuContent>;
    if (this.kind === 'article') {
      task = api.fetchArticle(this.contentId);
    } else if (this.kind === 'pin') {
      task = api.fetchPin(this.contentId);
    } else {
      task = api.fetchAnswer(this.contentId);
    }
    task
      .then((content: ZhihuContent): void => {
        this.content = content;
        this.voteCount = content.voteupCount;
        this.voted = content.voting === 1;
        this.pageTitle = this.kind === 'answer' ? content.title :
          (this.kind === 'article' ? content.title : '想法');
        this.documentHtml = this.buildDocument(content);
        this.isLoading = false;
        this.contentReady = true;
        this.applyDocument();
        HistoryStore.getInstance().record(getContext(this), this.kind, this.contentId, content.title)
          .catch((): void => {});
      })
      .catch((error: ZhihuHttpError): void => {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = error.message;
      });
  }

  private applyDocument(): void {
    if (this.documentHtml.length === 0) {
      return;
    }
    try {
      this.webController.loadData(this.documentHtml, 'text/html', 'utf-8');
    } catch (error) {
      // retry once after web view mounts
      setTimeout((): void => {
        try {
          this.webController.loadData(this.documentHtml, 'text/html', 'utf-8');
        } catch (ignored) {
          // content may fail to render on slow mounts
        }
      }, 300);
    }
  }

  private toggleVote(): void {
    const session = ZhihuSession.getInstance();
    if (!session.isLoggedIn()) {
      showToast(this.getUIContext(), '请先登录');
      return;
    }
    const nextVoted = !this.voted;
    const apiKind = this.kind === 'article' ? 'articles' : 'answers';
    ZhihuApi.getInstance().voteContent(apiKind, this.contentId, nextVoted ? 'up' : 'neutral')
      .then((): void => {
        this.voted = nextVoted;
        this.voteCount = this.voteCount + (nextVoted ? 1 : -1);
      })
      .catch((error: ZhihuHttpError): void => {
        showToast(this.getUIContext(), '操作失败：' + error.message.substring(0, 60));
      });
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Web({ src: 'about:blank', controller: this.webController })
            .layoutWeight(1)

          if (this.content !== null) {
            Row({ space: 10 }) {
              if (this.content.authorAvatar.length > 0) {
                Image(this.content.authorAvatar)
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .backgroundColor('#EEEEEE')
              } else {
                Circle({ width: 28, height: 28 })
                  .fill('#DDDDDD')
              }
              Column({ space: 2 }) {
                Text(this.content.authorName.length > 0 ? this.content.authorName : '匿名用户')
                  .fontSize(14)
                  .fontColor(APP_COLOR_TEXT)
                  .maxLines(1)
                if (this.content.createdTime > 0) {
                  Text('编辑于 ' + formatRelativeTime(this.content.createdTime))
                    .fontSize(11)
                    .fontColor(APP_COLOR_SECONDARY)
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
            .onClick(() => {
              if (this.content !== null && this.content.authorToken.length > 0) {
                const param: PeoplePageParam = { urlToken: this.content.authorToken };
                this.pathStack.pushPathByName('people', param);
              }
            })
          }

          Row() {
            Button(this.voted ? '已赞同 ' + this.voteCount : '赞同 ' + this.voteCount)
              .fontSize(14)
              .height(34)
              .backgroundColor(this.voted ? APP_COLOR_BLUE : '#F0F0F0')
              .fontColor(this.voted ? '#FFFFFF' : APP_COLOR_TEXT)
              .onClick(() => {
                this.toggleVote();
              })

            Blank()

            Row({ space: 4 }) {
              Text('评论')
                .fontSize(13)
                .fontColor(APP_COLOR_TEXT)
              if (this.content !== null && this.content.commentCount > 0) {
                Text(String(this.content.commentCount))
                  .fontSize(13)
                  .fontColor(APP_COLOR_SECONDARY)
              }
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F0F0F0')
            .borderRadius(17)
            .onClick(() => {
              this.openComments();
            })

            Row({ space: 4 }) {
              Text('分享')
                .fontSize(13)
                .fontColor(APP_COLOR_TEXT)
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F0F0F0')
            .borderRadius(17)
            .onClick(() => {
              this.shareContent();
            })

            Row({ space: 4 }) {
              Text('浏览器打开')
                .fontSize(13)
                .fontColor(APP_COLOR_TEXT)
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('#F0F0F0')
            .borderRadius(17)
            .onClick(() => {
              this.openInExternal();
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#FFFFFF')
        }
        .width('100%')
        .height('100%')
        .visibility((this.isLoading || this.hasError) ? Visibility.Hidden : Visibility.Visible)

        if (this.isLoading) {
          LoadingView()
        }
        if (this.hasError) {
          ErrorView({
            message: this.errorMessage,
            onRetry: (): void => {
              this.load();
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .title(this.pageTitle)
    .backgroundColor('#FFFFFF')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as ContentPageParam;
      this.kind = param.kind;
      this.contentId = param.id;
      if (this.kind !== 'answer' && this.kind !== 'article' && this.kind !== 'pin') {
        this.kind = 'answer';
      }
      this.load();
    })
  }

  private openComments(): void {
    if (this.content === null) {
      return;
    }
    const kind = this.kind === 'article' ? 'articles' : (this.kind === 'pin' ? 'pins' : 'answers');
    const param: CommentsPageParam = { kind: kind, id: this.contentId, title: this.pageTitle };
    this.pathStack.pushPathByName('comments', param);
  }

  private shareContent(): void {
    if (this.content === null) {
      return;
    }
    copyToClipboard(this.getUIContext(), this.content.shareUrl);
  }

  private openInExternal(): void {
    if (this.content === null) {
      return;
    }
    openInBrowser(getContext(this), this.content.shareUrl);
  }
}

@Builder
export function ContentBuilder() {
  ContentPage()
}
