import { webview } from '@kit.ArkWeb';
import { isZhihuVerificationPage, ZHIHU_QR_UA, ZHIHU_RISK_CONTROL_URL, ZhihuSession } from '@ohos/common';
import { APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_SECONDARY } from './NavHelper';

const COOKIE_URL: string = 'https://www.zhihu.com/';

@Component
export struct QrSecurityVerificationPane {
  @Prop url: string = ZHIHU_RISK_CONTROL_URL;
  @Prop initialCookies: string = '';
  onReturnToQr: (cookies: string) => void = () => {};
  @State private failed: boolean = false;
  private readonly controller = new webview.WebviewController();
  private loadAfterBlank: boolean = false;

  private targetUrl(): string {
    return isZhihuVerificationPage(this.url) ? this.url : ZHIHU_RISK_CONTROL_URL;
  }

  private launch(): void {
    if (this.initialCookies) {
      const context = new ZhihuSession();
      context.applyCookieString(this.initialCookies);
      context.removeCookie('z_c0');
      for (const field of context.cookieHeader().split('; ')) {
        if (field.length > 0) {
          webview.WebCookieManager.configCookieSync(COOKIE_URL, field + '; Domain=.zhihu.com; Path=/; Secure', true);
        }
      }
      this.loadAfterBlank = true;
    }
  }

  private loadPage(): void {
    this.failed = false;
    try {
      this.controller.loadUrl(this.targetUrl());
    } catch (error) {
      this.failed = true;
    }
  }

  private returnToQr(): void {
    let cookies = '';
    try {
      cookies = webview.WebCookieManager.fetchCookieSync(COOKIE_URL, true);
    } catch (error) {
      // The QR request will initialize a fresh session if no cookies are available.
    }
    const session = new ZhihuSession();
    session.applyCookieString(cookies);
    session.removeCookie('z_c0');
    this.onReturnToQr(session.cookieHeader());
  }

  build() {
    Column() {
      Web({
        src: this.initialCookies ? 'about:blank' : this.targetUrl(),
        controller: this.controller,
        incognitoMode: true
      })
        .width('100%')
        .layoutWeight(1)
        .userAgent(ZHIHU_QR_UA)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.None)
        .onControllerAttached(() => {
          try {
            this.launch();
          } catch (error) {
            this.failed = true;
          }
        })
        .onLoadIntercept((event) => {
          const request = event.data;
          const url = request.getRequestUrl();
          return request.isMainFrame() && url !== 'about:blank' && !isZhihuVerificationPage(url);
        })
        .onPageEnd((event) => {
          if (this.loadAfterBlank && event?.url === 'about:blank') {
            this.loadAfterBlank = false;
            this.loadPage();
          }
        })
        .onErrorReceive((event) => {
          if (event?.request.isMainFrame()) {
            this.failed = true;
          }
        })
      if (this.failed) {
        Text('知乎安全验证加载失败')
          .fontSize(13)
          .fontColor(APP_COLOR_SECONDARY)
          .margin({ top: 8 })
      }
      Button(this.failed ? '重新加载' : '验证完成，返回扫码')
        .height(44)
        .width('90%')
        .fontSize(14)
        .fontColor(APP_COLOR_BLUE)
        .backgroundColor('#EDF4FF')
        .margin({ top: 10, bottom: 12 })
        .onClick(() => {
          if (this.failed) {
            this.loadPage();
          } else {
            this.returnToQr();
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLOR_CARD)
  }
}
