import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { pageTitleBar, MINI_TITLE_BAR_HEIGHT } from '../view/NavigationChrome';
/**
 * Zhihu Daily story reader, ported from DailyStoryScreen.kt. Story body rendered in Web.
 */
import { webview } from '@kit.ArkWeb';
import { HistoryStore, ZhihuApi, ZhihuDailyDetail } from '@ohos/common';
import { loadReaderDocument, updateReaderTopInset } from '../view/ReaderDocument';
import { LoadingView, ErrorView } from '../view/Widgets';
import { DailyStoryPageParam } from '../view/NavHelper';

@Component
export struct DailyStoryPage {
  pathStack: NavPathStack = new NavPathStack();
  @State detail: ZhihuDailyDetail | null = null;
  @StorageProp('statusBarHeightPx') @Watch('updateTopInset') private statusBarHeightPx: number = 0;
  @State private webScrollOffset: number = 0;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  private storyId: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();
  private documentHtml: string = '';
  private webReady: boolean = false;

  private getTitleInset(): number {
    return MINI_TITLE_BAR_HEIGHT + this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  private updateTopInset(): void {
    if (this.webReady) {
      updateReaderTopInset(this.webController, this.getTitleInset());
    }
  }

  private buildDocument(detail: ZhihuDailyDetail): string {
    const css: string = 'body{margin:0;padding:16px;font-size:16px;line-height:1.75;color:#1A1A1A;' +
      'padding-top:calc(var(--reader-top-inset,' + this.getTitleInset() + 'px) + 16px);' +
      'word-break:break-word;background:#FFFFFF;font-family:"HarmonyOS Sans SC","PingFang SC","Microsoft YaHei",sans-serif;}' +
      'img{max-width:100%;height:auto;border-radius:4px;}' +
      'a{color:#0066FF;text-decoration:none;}' +
      'p{margin:0 0 12px 0;}' +
      'h1,h2,h3{margin:16px 0 8px 0;font-weight:bold;}' +
      'blockquote{margin:12px 0;padding:8px 12px;border-left:3px solid #E8E8E8;background:#F8F8F8;color:#555555;}' +
      'hr{border:none;border-top:1px solid #F0F0F0;margin:16px 0;}';
    const header: string = detail.imageSource.length > 0 ?
      '<p style="font-size:12px;color:#999999;">图片：' + detail.imageSource + '</p>' : '';
    return '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=3">' +
      '<style>' + css + '</style></head><body>' + header + detail.bodyHtml + '</body></html>';
  }

  private load(): void {
    this.isLoading = true;
    this.webScrollOffset = 0;
    this.hasError = false;
    this.documentHtml = '';
    ZhihuApi.getInstance().fetchDailyStory(this.storyId)
      .then((detail: ZhihuDailyDetail): void => {
        this.detail = detail;
        if (detail.bodyHtml.trim().length === 0) {
          throw new Error('知乎日报未返回正文，请重试');
        }
        this.documentHtml = this.buildDocument(detail);
        this.applyDocument();
        HistoryStore.getInstance().record(getContext(this), 'daily', this.storyId, detail.title)
          .catch((): void => {});
      })
      .catch((error: Error): void => {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage = error.message;
      });
  }

  private applyDocument(): void {
    if (!this.webReady || this.documentHtml.length === 0) {
      return;
    }
    try {
      loadReaderDocument(this.webController, this.documentHtml);
      this.isLoading = false;
    } catch (error) {
      this.isLoading = false;
      this.hasError = true;
      this.errorMessage = '正文渲染失败，请重试';
    }
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Web({ src: 'about:blank', controller: this.webController, renderMode: RenderMode.SYNC_RENDER })
          .width('100%')
          .height(LayoutPolicy.matchParent)
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
          .onScroll((event: OnScrollEvent) => {
            this.webScrollOffset = Math.min(this.getTitleInset(), Math.round(Math.max(0, event.yOffset)));
          })
          .onPageEnd((event) => {
            if (!this.webReady && event?.url === 'about:blank') {
              this.webReady = true;
              this.applyDocument();
            }
          })
          .onErrorReceive((event) => {
            if (event?.request.isMainFrame()) {
              this.isLoading = false;
              this.hasError = true;
              this.errorMessage = '正文渲染失败，请重试';
            }
          })
          .visibility(this.isLoading || this.hasError ? Visibility.Hidden : Visibility.Visible)
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
      .height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar(this.detail?.title || '日报', this.getTitleInset(), this.webScrollOffset))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor('#FFFFFF')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as DailyStoryPageParam;
      this.storyId = param.id;
      this.load();
    })
  }
}

@Builder
export function DailyStoryBuilder() {
  DailyStoryPage()
}
