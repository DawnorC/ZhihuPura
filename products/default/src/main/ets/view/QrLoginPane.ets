import {
  ZhihuHttpError, ZhihuLoginVerificationError, ZhihuQrLogin, ZhihuQrLoginStatus, ZhihuQrTicket
} from '@ohos/common';
import { APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_SECONDARY, APP_COLOR_TEXT } from './NavHelper';

const POLL_INTERVAL: number = 1500;

@Component
export struct QrLoginPane {
  @Prop initialCookies: string = '';
  onAuthenticated: (cookies: string) => Promise<boolean> = () => Promise.resolve(false);
  onVerification: (url: string, cookies: string) => void = () => {};
  @State private qrLink: string = '';
  @State private status: string = '正在获取二维码…';
  @State private verificationUrl: string = '';
  @State private busy: boolean = false;
  private verificationCookies: string = '';
  private requestId: number = 0;
  private client?: ZhihuQrLogin;
  private pollTimer: number = -1;
  private networkFailures: number = 0;

  aboutToAppear(): void {
    this.refreshCode();
  }

  aboutToDisappear(): void {
    this.cancel();
  }

  private cancel(): void {
    this.requestId++;
    if (this.pollTimer >= 0) {
      clearTimeout(this.pollTimer);
      this.pollTimer = -1;
    }
    this.client?.close();
    this.client = undefined;
  }

  private finish(status: string): void {
    this.cancel();
    this.qrLink = '';
    this.status = status;
    this.busy = false;
  }

  private fail(error: Error, client: ZhihuQrLogin): void {
    if (error instanceof ZhihuLoginVerificationError) {
      this.verificationUrl = error.verificationUrl;
      this.verificationCookies = client.cookieHeader();
    }
    const message = error instanceof ZhihuHttpError ? '连接知乎失败，请重试' : error.message;
    this.finish(message || '扫码登录失败，请重试');
  }

  private async refreshCode(): Promise<void> {
    this.cancel();
    this.qrLink = '';
    this.verificationUrl = '';
    this.verificationCookies = '';
    this.status = '正在获取二维码…';
    this.busy = true;
    this.networkFailures = 0;
    const requestId = this.requestId;
    const client = new ZhihuQrLogin(this.initialCookies);
    this.client = client;
    try {
      const ticket = await client.createTicket();
      if (this.requestId !== requestId) {
        return;
      }
      if (ticket.deadline <= Date.now()) {
        this.finish('二维码已过期，请重新获取');
        return;
      }
      this.qrLink = ticket.link;
      this.status = '等待扫码';
      this.busy = false;
      this.schedulePoll(ticket, client, requestId);
    } catch (error) {
      if (this.requestId === requestId) {
        this.fail(error as Error, client);
      }
    }
  }

  private schedulePoll(ticket: ZhihuQrTicket, client: ZhihuQrLogin, requestId: number): void {
    const delay = Math.min(POLL_INTERVAL, Math.max(0, ticket.deadline - Date.now()));
    this.pollTimer = setTimeout((): void => {
      this.pollTimer = -1;
      this.poll(ticket, client, requestId);
    }, delay);
  }

  private async poll(ticket: ZhihuQrTicket, client: ZhihuQrLogin, requestId: number): Promise<void> {
    try {
      const result = await client.poll(ticket);
      if (this.requestId !== requestId) {
        return;
      }
      this.networkFailures = 0;
      if (result === ZhihuQrLoginStatus.Expired) {
        this.finish('二维码已过期，请重新获取');
        return;
      }
      if (result === ZhihuQrLoginStatus.Confirmed) {
        this.busy = true;
        this.qrLink = '';
        this.status = '正在校验知乎账号…';
        const authenticated = await this.onAuthenticated(client.cookieHeader());
        if (!authenticated && this.requestId === requestId) {
          this.finish('账号校验失败，请重新获取二维码');
        }
        return;
      }
      if (result === ZhihuQrLoginStatus.Scanned) {
        this.status = '已扫码，请在知乎 App 确认登录';
      }
    } catch (error) {
      if (this.requestId !== requestId) {
        return;
      }
      this.networkFailures++;
      if (!(error instanceof ZhihuHttpError) || error.status !== -1 || this.networkFailures >= 3) {
        this.fail(error as Error, client);
        return;
      }
    }
    this.schedulePoll(ticket, client, requestId);
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.qrLink) {
          QRCode(this.qrLink)
            .width(216)
            .height(216)
            .color('#111111')
            .backgroundColor(APP_COLOR_CARD)
            .margin({ top: 12 })
            .accessibilityText('知乎登录二维码')
          Text('打开知乎 App，在「我的」右上角找到扫一扫')
            .textAlign(TextAlign.Center)
            .fontSize(14)
            .fontColor(APP_COLOR_SECONDARY)
        } else if (this.busy) {
          LoadingProgress().width(34).height(34).color(APP_COLOR_BLUE)
        }
        Text(this.status)
          .fontSize(15)
          .fontColor(APP_COLOR_TEXT)
          .textAlign(TextAlign.Center)
        if (this.verificationUrl) {
          Button('完成知乎安全验证')
            .height(44)
            .backgroundColor(APP_COLOR_BLUE)
            .onClick((): void => { this.onVerification(this.verificationUrl, this.verificationCookies); })
        } else if (!this.busy) {
          Button(this.qrLink ? '刷新二维码' : '重新获取二维码')
            .height(44)
            .fontColor(APP_COLOR_BLUE)
            .backgroundColor('#EDF4FF')
            .onClick((): void => { this.refreshCode(); })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 32, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(APP_COLOR_CARD)
  }
}
