/**
 * Generic web fallback page (videos and other unsupported targets open here).
 */
import { webview } from '@kit.ArkWeb';
import { WebPageParam } from '../view/NavHelper';

@Component
export struct WebPage {
  pathStack: NavPathStack = new NavPathStack();
  @State pageTitle: string = '';
  private url: string = '';
  private webController: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Stack() {
        Web({ src: this.url, controller: this.webController })
          .width('100%')
          .height('100%')
          .onControllerAttached(() => {
            try {
              this.webController.loadUrl(this.url);
            } catch (error) {
              // url may already be loading
            }
          })
      }
      .width('100%')
      .height('100%')
    }
    .title(this.pageTitle)
    .backgroundColor('#FFFFFF')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      const param = context.pathInfo.param as WebPageParam;
      this.url = param.url;
      this.pageTitle = param.title;
    })
  }
}

@Builder
export function WebBuilder() {
  WebPage()
}
