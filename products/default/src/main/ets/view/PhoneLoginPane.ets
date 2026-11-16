import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { normalizeZhihuPhoneNumber, ZhihuHttpError, ZhihuPhoneLogin } from '@ohos/common';
import { APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_SECONDARY, APP_COLOR_TEXT, openInBrowser } from './NavHelper';

const FIELD_SURFACE: string = '#F5F6F8';

enum PhoneLoginOperation {
  Idle,
  Send,
  Captcha,
  Login
}

@Component
export struct PhoneLoginPane {
  onAuthenticated: (cookies: string) => Promise<boolean> = () => Promise.resolve(false);
  @State private phone: string = '';
  @State private digits: string = '';
  @State private agreementAccepted: boolean = false;
  @State private phoneWithCode: string = '';
  @State private captchaRequired: boolean = false;
  @State private captchaInput: string = '';
  @State private captchaImage: image.PixelMap | undefined = undefined;
  @State private cooldown: number = 0;
  @State private status: string = '';
  @State private error: string = '';
  @State private operation: PhoneLoginOperation = PhoneLoginOperation.Idle;
  private client?: ZhihuPhoneLogin;
  private cooldownTimer: number = -1;

  aboutToAppear(): void {
    this.client = new ZhihuPhoneLogin();
  }

  aboutToDisappear(): void {
    this.client?.close();
    this.client = undefined;
    this.stopCooldown();
    this.clearCaptcha();
    this.phone = '';
    this.phoneWithCode = '';
    this.digits = '';
  }

  private stopCooldown(): void {
    if (this.cooldownTimer !== -1) {
      clearInterval(this.cooldownTimer);
      this.cooldownTimer = -1;
    }
  }

  private startCooldown(): void {
    this.stopCooldown();
    const deadline = Date.now() + 60000;
    this.cooldown = 60;
    this.cooldownTimer = setInterval((): void => {
      this.cooldown = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
      if (this.cooldown === 0) {
        this.stopCooldown();
      }
    }, 1000);
  }

  private clearCaptchaImage(): void {
    const previous = this.captchaImage;
    this.captchaImage = undefined;
    if (previous) {
      previous.release().catch((): void => {});
    }
  }

  private clearCaptcha(): void {
    this.captchaRequired = false;
    this.captchaInput = '';
    this.clearCaptchaImage();
  }

  private updatePhone(input: string): void {
    const normalized = normalizeZhihuPhoneNumber(input);
    const phone = normalized ? normalized.slice(3) : input.replace(/\D/g, '').slice(0, 11);
    if (phone !== this.phone) {
      this.phone = phone;
      this.phoneWithCode = '';
      this.digits = '';
      this.clearCaptcha();
      this.error = '';
      this.status = '';
    }
  }

  private async showCaptcha(client: ZhihuPhoneLogin, imageBase64: string | undefined): Promise<void> {
    this.captchaRequired = true;
    this.captchaInput = '';
    this.clearCaptchaImage();
    const data = imageBase64?.replace(/^data:image\/(?:png|jpeg|webp);base64,/i, '').replace(/\s/g, '') ?? '';
    if (!data || data.length > 524288 || !/^[A-Za-z0-9+/]+={0,2}$/.test(data)) {
      throw new Error('知乎未返回可用的图形验证码，请换一张');
    }
    const bytes = new util.Base64Helper().decodeSync(data);
    const source = image.createImageSource(bytes.buffer as ArrayBuffer);
    try {
      const pixelMap = await source.createPixelMap();
      if (this.client === client) {
        this.captchaImage = pixelMap;
      } else {
        await pixelMap.release();
      }
    } finally {
      await source.release();
    }
  }

  private canSend(): boolean {
    return this.operation === PhoneLoginOperation.Idle && this.agreementAccepted && this.cooldown === 0 &&
      !!normalizeZhihuPhoneNumber(this.phone);
  }

  private canLogin(): boolean {
    return this.operation === PhoneLoginOperation.Idle && this.agreementAccepted &&
      this.phoneWithCode.length > 0 && this.phoneWithCode === normalizeZhihuPhoneNumber(this.phone) &&
      /^\d{6}$/.test(this.digits);
  }

  private setError(error: Error): void {
    this.error = error instanceof ZhihuHttpError ? '连接知乎失败，请重试' : error.message || '登录请求失败，请重试';
  }

  private async sendCode(verifyCaptcha: boolean = false): Promise<void> {
    const client = this.client;
    if (!client || !this.canSend() || (verifyCaptcha && (!this.captchaInput.trim() || !this.captchaImage))) {
      return;
    }
    const phone = normalizeZhihuPhoneNumber(this.phone);
    this.operation = PhoneLoginOperation.Send;
    this.error = '';
    this.status = '';
    try {
      if (verifyCaptcha && !await client.verifyCaptcha(this.captchaInput)) {
        if (this.client === client) {
          await this.showCaptcha(client, await client.refreshCaptcha());
          if (this.client === client) {
            this.error = '图形验证码不正确，请重试';
          }
        }
        return;
      }
      const result = await client.requestDigits(phone);
      if (this.client !== client) {
        return;
      }
      if (result.captchaRequired) {
        await this.showCaptcha(client, result.captchaImage);
        return;
      }
      this.clearCaptcha();
      this.phoneWithCode = phone;
      this.digits = '';
      this.status = '短信验证码已发送';
      this.startCooldown();
    } catch (error) {
      if (this.client === client) {
        this.setError(error as Error);
      }
    } finally {
      if (this.client === client) {
        this.operation = PhoneLoginOperation.Idle;
      }
    }
  }

  private async refreshCaptcha(): Promise<void> {
    const client = this.client;
    if (!client || this.operation !== PhoneLoginOperation.Idle || !this.captchaRequired) {
      return;
    }
    this.operation = PhoneLoginOperation.Captcha;
    this.error = '';
    this.captchaInput = '';
    this.clearCaptchaImage();
    try {
      const data = await client.refreshCaptcha();
      if (this.client === client) {
        await this.showCaptcha(client, data);
      }
    } catch (error) {
      if (this.client === client) {
        this.setError(error as Error);
      }
    } finally {
      if (this.client === client) {
        this.operation = PhoneLoginOperation.Idle;
      }
    }
  }

  private async login(): Promise<void> {
    const client = this.client;
    if (!client || !this.canLogin()) {
      return;
    }
    this.operation = PhoneLoginOperation.Login;
    this.error = '';
    this.status = '';
    try {
      const cookies = await client.signIn(this.phoneWithCode, this.digits);
      if (this.client === client) {
        await this.onAuthenticated(cookies);
      }
    } catch (error) {
      if (this.client === client) {
        this.setError(error as Error);
      }
    } finally {
      if (this.client === client) {
        this.operation = PhoneLoginOperation.Idle;
      }
    }
  }

  private openPolicy(url: string): void {
    const context = this.getUIContext().getHostContext();
    if (context) {
      openInBrowser(context, url);
    }
  }

  @Builder
  captchaFields() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        if (this.captchaImage) {
          Image(this.captchaImage)
            .width(126)
            .height(46)
            .objectFit(ImageFit.Contain)
            .borderRadius(8)
            .accessibilityText('图形验证码')
        }
        Button(this.operation === PhoneLoginOperation.Captcha ? '获取中…' : '换一张')
          .height(44)
          .fontSize(13)
          .fontColor(APP_COLOR_BLUE)
          .backgroundColor('#EDF4FF')
          .enabled(this.operation === PhoneLoginOperation.Idle)
          .onClick((): void => { this.refreshCaptcha(); })
      }
      .width('100%')
      Row({ space: 10 }) {
        TextInput({ placeholder: '图形验证码', text: this.captchaInput })
          .layoutWeight(1)
          .height(48)
          .backgroundColor(FIELD_SURFACE)
          .maxLength(32)
          .enabled(this.operation === PhoneLoginOperation.Idle)
          .onChange((value: string): void => { this.captchaInput = value; })
          .onSubmit((): void => { this.sendCode(true); })
        Button('验证并发送')
          .height(44)
          .fontSize(13)
          .fontColor(APP_COLOR_BLUE)
          .backgroundColor('#EDF4FF')
          .enabled(this.canSend() && this.captchaInput.trim().length > 0 && !!this.captchaImage)
          .onClick((): void => { this.sendCode(true); })
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row({ space: 4 }) {
          Text('+86')
            .fontColor(APP_COLOR_TEXT)
            .fontSize(16)
            .padding({ left: 16 })
          TextInput({ placeholder: '请输入手机号', text: this.phone })
            .layoutWeight(1)
            .fontSize(16)
            .height(52)
            .type(InputType.PhoneNumber)
            .backgroundColor(Color.Transparent)
            .enabled(this.operation === PhoneLoginOperation.Idle)
            .id('zhihu-login-phone')
            .onChange((value: string): void => { this.updatePhone(value); })
        }
        .width('100%')
        .height(52)
        .borderRadius(26)
        .backgroundColor(FIELD_SURFACE)

        if (this.captchaRequired) {
          this.captchaFields()
        }

        Row({ space: 10 }) {
          TextInput({ placeholder: '6 位短信验证码', text: this.digits })
            .layoutWeight(1)
            .height(52)
            .fontSize(16)
            .type(InputType.ONE_TIME_CODE)
            .maxLength(6)
            .backgroundColor(FIELD_SURFACE)
            .enabled(this.operation === PhoneLoginOperation.Idle)
            .id('zhihu-login-sms')
            .onChange((value: string): void => { this.digits = value.replace(/\D/g, ''); })
            .onSubmit((): void => { this.login(); })
          Button(this.operation === PhoneLoginOperation.Send ? '发送中…' :
            (this.cooldown > 0 ? this.cooldown + ' 秒后重发' : '发送验证码'))
            .height(44)
            .fontSize(13)
            .fontColor(APP_COLOR_BLUE)
            .backgroundColor('#EDF4FF')
            .enabled(this.canSend() && !this.captchaRequired)
            .id('zhihu-login-send')
            .onClick((): void => { this.sendCode(); })
        }
        .width('100%')

        Row({ space: 8 }) {
          Checkbox({ name: 'zhihu-login-agreement' })
            .select(this.agreementAccepted)
            .selectedColor(APP_COLOR_BLUE)
            .enabled(this.operation === PhoneLoginOperation.Idle)
            .accessibilityText('同意知乎协议及个人信息保护指引')
            .onChange((accepted: boolean): void => { this.agreementAccepted = accepted; })
          Text() {
            Span('我已阅读并同意')
            Span('《知乎协议》')
              .fontColor(APP_COLOR_BLUE)
              .onClick((): void => { this.openPolicy('https://www.zhihu.com/term/zhihu-terms'); })
            Span('《个人信息保护指引》')
              .fontColor(APP_COLOR_BLUE)
              .onClick((): void => { this.openPolicy('https://www.zhihu.com/term/privacy'); })
          }
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(APP_COLOR_SECONDARY)
          .lineHeight(20)
        }
        .width('100%')

        if (this.error || this.status) {
          Text(this.error || this.status)
            .fontSize(13)
            .fontColor(this.error ? '#B93738' : APP_COLOR_SECONDARY)
            .width('100%')
        }

        Button(this.operation === PhoneLoginOperation.Login ? '正在登录…' : '登录')
          .width('100%')
          .height(48)
          .backgroundColor(APP_COLOR_BLUE)
          .enabled(this.canLogin())
          .id('zhihu-login-submit')
          .onClick((): void => { this.login(); })
      }
      .constraintSize({ maxWidth: 480 })
      .width('100%')
      .padding({ left: 24, right: 24, top: 28, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(APP_COLOR_CARD)
  }
}
