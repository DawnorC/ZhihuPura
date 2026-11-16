import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { ZhihuApi, ZhihuHttpError, ZhihuSession } from '@ohos/common';
import { pageTitleBar } from '../view/NavigationChrome';
import { PhoneLoginPane } from '../view/PhoneLoginPane';
import { QrLoginPane } from '../view/QrLoginPane';
import { QrSecurityVerificationPane } from '../view/QrSecurityVerificationPane';
import { showToast, syncCookiesToWebView, APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_SECONDARY,
  APP_COLOR_TEXT } from '../view/NavHelper';

enum LoginMethod {
  Phone,
  Qr,
  Cookie
}

@Component
export struct LoginPage {
  pathStack: NavPathStack = new NavPathStack();
  @State private method: LoginMethod = LoginMethod.Phone;
  @State private verificationUrl: string = '';
  @State private cookieInput: string = '';
  @State private isSubmitting: boolean = false;
  @State private errorMessage: string = '';
  private qrCookies: string = '';
  private verificationCookies: string = '';
  private attempt: number = 0;

  aboutToDisappear(): void {
    this.attempt++;
    this.cookieInput = '';
    this.qrCookies = '';
    this.verificationCookies = '';
  }

  private selectMethod(method: LoginMethod): void {
    if (this.method === method || this.isSubmitting) {
      return;
    }
    this.attempt++;
    this.method = method;
    this.errorMessage = '';
    this.cookieInput = '';
    this.verificationUrl = '';
    this.verificationCookies = '';
    this.qrCookies = '';
  }

  private showVerification(url: string, cookies: string): void {
    this.verificationCookies = cookies;
    this.verificationUrl = url;
  }

  private returnToQr(cookies: string): void {
    this.qrCookies = cookies;
    this.verificationCookies = '';
    this.verificationUrl = '';
    this.errorMessage = '';
  }

  private async authenticate(cookies: string): Promise<boolean> {
    if (this.isSubmitting) {
      return false;
    }
    const attempt = ++this.attempt;
    const session = ZhihuSession.getInstance();
    this.isSubmitting = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('登录页面未就绪，请重试');
      }
      await session.init(context);
      const candidate = await ZhihuApi.getInstance().verifyLoginCookie(cookies.trim());
      if (this.attempt !== attempt) {
        return false;
      }
      await session.adoptVerifiedSession(candidate);
      AppStorage.setOrCreate('zhihuLoggedIn', true);
      AppStorage.setOrCreate('zhihuUserName', session.user.name);
      AppStorage.setOrCreate('zhihuUserAvatar', session.user.avatarUrl);
      syncCookiesToWebView();
      if (this.attempt === attempt) {
        this.cookieInput = '';
        showToast(this.getUIContext(), '登录成功');
        this.pathStack.pop();
      }
      return true;
    } catch (error) {
      if (this.attempt === attempt) {
        this.errorMessage = error instanceof ZhihuHttpError ? '连接知乎失败，请重试' :
          (error as Error).message || '登录失败，请重试';
      }
      return false;
    } finally {
      if (this.attempt === attempt) {
        this.isSubmitting = false;
      }
    }
  }

  @Builder
  methodButton(title: string, method: LoginMethod) {
    Button(title)
      .layoutWeight(1)
      .height(42)
      .fontSize(14)
      .fontColor(this.method === method ? APP_COLOR_BLUE : APP_COLOR_TEXT)
      .backgroundColor(this.method === method ? '#EDF4FF' : Color.Transparent)
      .enabled(!this.isSubmitting)
      .accessibilitySelected(this.method === method)
      .onClick(() => { this.selectMethod(method); })
  }

  @Builder
  cookiePane() {
    Scroll() {
      Column({ space: 16 }) {
        Text('粘贴已登录知乎网页的 Cookie')
          .fontSize(14)
          .fontColor(APP_COLOR_SECONDARY)
          .width('100%')
        TextArea({ placeholder: 'z_c0=…', text: this.cookieInput })
          .fontSize(14)
          .height(112)
          .width('100%')
          .borderRadius(12)
          .backgroundColor('#F5F6F8')
          .onChange((value: string) => { this.cookieInput = value; })
        Button(this.isSubmitting ? '正在校验…' : '登录')
          .height(44)
          .width('100%')
          .backgroundColor(APP_COLOR_BLUE)
          .enabled(!this.isSubmitting && this.cookieInput.trim().length > 0)
          .onClick(() => { this.authenticate(this.cookieInput); })
      }
      .constraintSize({ maxWidth: 480 })
      .width('100%')
      .padding({ left: 24, right: 24, top: 28, bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavDestination() {
      Column() {
        Row({ space: 4 }) {
          this.methodButton('手机号登录', LoginMethod.Phone)
          this.methodButton('二维码登录', LoginMethod.Qr)
          this.methodButton('Cookie', LoginMethod.Cookie)
        }
        .padding(4)
        .width('92%')
        .constraintSize({ maxWidth: 480 })
        .backgroundColor('#F5F6F8')
        .borderRadius(25)
        .margin({ top: 8, bottom: 10 })

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#B93738')
            .padding({ left: 18, right: 18, bottom: 8 })
        }

        Column() {
          if (this.method === LoginMethod.Phone) {
            PhoneLoginPane({
              onAuthenticated: (cookies: string): Promise<boolean> => this.authenticate(cookies)
            })
          } else if (this.method === LoginMethod.Qr && !this.verificationUrl) {
            QrLoginPane({
              initialCookies: this.qrCookies,
              onAuthenticated: (cookies: string): Promise<boolean> => this.authenticate(cookies),
              onVerification: (url: string, cookies: string): void => { this.showVerification(url, cookies); }
            })
          } else if (this.method === LoginMethod.Cookie) {
            this.cookiePane()
          } else {
            QrSecurityVerificationPane({
              url: this.verificationUrl,
              initialCookies: this.verificationCookies,
              onReturnToQr: (cookies: string): void => { this.returnToQr(cookies); }
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(APP_COLOR_CARD)
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar('登录知乎'))
    .backgroundColor(APP_COLOR_CARD)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Builder
export function LoginBuilder() {
  LoginPage()
}
