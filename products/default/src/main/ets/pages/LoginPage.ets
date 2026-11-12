/**
 * Login page, ported from LoginScreen.kt. Two modes:
 * 1. WebView login at zhihu.com/signin, cookies captured via WebCookieManager.
 * 2. Manual cookie string paste (must contain z_c0).
 */
import { webview } from '@kit.ArkWeb';
import { ZhihuApi, ZhihuSession } from '@ohos/common';
import { showToast, syncCookiesToWebView, APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_BG } from '../view/NavHelper';

@Component
export struct LoginPage {
  pathStack: NavPathStack = new NavPathStack();
  @State useWebLogin: boolean = true;
  @State cookieInput: string = '';
  @State isSubmitting: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  private finishLogin(): void {
    const session = ZhihuSession.getInstance();
    AppStorage.setOrCreate('zhihuLoggedIn', session.isLoggedIn());
    AppStorage.setOrCreate('zhihuUserName', session.user.name);
    AppStorage.setOrCreate('zhihuUserAvatar', session.user.avatarUrl);
    syncCookiesToWebView();
    showToast(this.getUIContext(), '登录成功');
    this.pathStack.pop();
  }

  private completeWebLogin(): void {
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    const session = ZhihuSession.getInstance();
    try {
      const cookieText = webview.WebCookieManager.fetchCookieSync('https://www.zhihu.com');
      if (cookieText.length > 0) {
        session.applyCookieString(cookieText);
      }
    } catch (error) {
      // cookie fetch is best-effort
    }
    if (!session.isLoggedIn()) {
      this.isSubmitting = false;
      showToast(this.getUIContext(), '未检测到登录状态，请先在页面中完成登录');
      return;
    }
    ZhihuApi.getInstance().refreshMe()
      .then((): void => {
        this.isSubmitting = false;
        this.finishLogin();
      })
      .catch((): void => {
        // cookie may still be valid even if /me fails
        this.isSubmitting = false;
        if (session.isLoggedIn()) {
          this.finishLogin();
        } else {
          showToast(this.getUIContext(), '登录信息校验失败，请重试');
        }
      });
  }

  private submitCookieString(): void {
    const cookieString = this.cookieInput.trim();
    if (cookieString.length === 0) {
      showToast(this.getUIContext(), '请粘贴 Cookie');
      return;
    }
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    ZhihuApi.getInstance().loginWithCookieString(cookieString)
      .then((): void => {
        this.isSubmitting = false;
        this.finishLogin();
      })
      .catch((): void => {
        this.isSubmitting = false;
        showToast(this.getUIContext(), 'Cookie 无效或已过期');
      });
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 8 }) {
          Text('网页登录')
            .fontSize(14)
            .fontColor(this.useWebLogin ? APP_COLOR_BLUE : APP_COLOR_TEXT)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(this.useWebLogin ? '#E8F1FF' : '#F0F0F0')
            .borderRadius(16)
            .onClick(() => {
              this.useWebLogin = true;
            })
          Text('粘贴 Cookie')
            .fontSize(14)
            .fontColor(!this.useWebLogin ? APP_COLOR_BLUE : APP_COLOR_TEXT)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(!this.useWebLogin ? '#E8F1FF' : '#F0F0F0')
            .borderRadius(16)
            .onClick(() => {
              this.useWebLogin = false;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 10 })

        if (this.useWebLogin) {
          Column() {
            Web({ src: 'https://www.zhihu.com/signin?next=%2F', controller: this.webController })
              .layoutWeight(1)
              .width('100%')
            Button(this.isSubmitting ? '校验中…' : '我已完成登录')
              .fontSize(15)
              .height(44)
              .width('90%')
              .backgroundColor(APP_COLOR_BLUE)
              .margin({ top: 12, bottom: 16 })
              .onClick(() => {
                this.completeWebLogin();
              })
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Column({ space: 12 }) {
            Text('从浏览器登录知乎后，复制完整 Cookie 字符串（必须包含 z_c0）并粘贴到下方')
              .fontSize(13)
              .fontColor(APP_COLOR_SECONDARY)
              .width('90%')
              .textAlign(TextAlign.Center)
            TextArea({ placeholder: 'z_c0=...; d_c0=...; _xsrf=...', text: this.cookieInput })
              .fontSize(13)
              .height(120)
              .width('90%')
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onChange((value: string) => {
                this.cookieInput = value;
              })
            Button(this.isSubmitting ? '校验中…' : '登录')
              .fontSize(15)
              .height(44)
              .width('90%')
              .backgroundColor(APP_COLOR_BLUE)
              .onClick(() => {
                this.submitCookieString();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(APP_COLOR_BG)
    }
    .title('登录知乎')
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Builder
export function LoginBuilder() {
  LoginPage()
}
