/**
 * Port of Zhihu++ ZhihuPhoneLoginClient.kt for HarmonyOS.
 * Copyright (C) 2024-2026 zly2006 <i@zly2006.me>
 * SPDX-License-Identifier: AGPL-3.0-only
 */
import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { ZhihuHttp, ZhihuHttpResponse } from './ZhihuHttp';
import { encryptPhoneLoginForm, signPhoneLoginRequest } from './ZhihuPhoneLoginCrypto';
import { ZhihuSession } from './ZhihuSession';

const GUEST_PATH: string = '/api/account/prod/init/udid_guest';
const CAPTCHA_PATH: string = '/captcha';
const DIGITS_PATH: string = '/api/account/prod/auth/digits';
const SIGN_IN_PATH: string = '/api/account/prod/sign_in';
const CLIENT_ID: string = "8d5227e0aaaa4797a763ac64e0c3b8";
const CLIENT_SECRET: string = "ecbefbf6b17e47ecb9035107866380";
const CLIENT_SOURCE: string = 'com.zhihu.android';
const CLOUD_APP_ID: string = '1355';
const CLOUD_APP_SECRET: string = "dd49a835-56e7-4a0f-95b5-efd51ea5397f";
const CLOUD_SIGN_VERSION: string = '2';
const PHONE_LOGIN_UA: string =
  'com.zhihu.android/Futureve/11.4.0 Mozilla/5.0 (Linux; Android 12; Android SDK built for arm64 ' +
  'Build/SE1A.220621.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 ' +
  'Chrome/57.0.1000.10 Mobile Safari/537.36';

interface LoginToken {
  access_token?: string;
  cookie?: Record<string, string>;
}

interface PhoneLoginReply extends LoginToken {
  guest?: LoginToken;
  udid?: string;
  show_captcha?: boolean;
  img_base64?: string;
  success?: boolean;
  error?: PhoneLoginError;
  code?: number;
}

interface PhoneLoginError {
  code?: number;
}

export interface ZhihuPhoneDigitsResult {
  captchaRequired: boolean;
  captchaImage?: string;
}

export function normalizeZhihuPhoneNumber(input: string): string {
  const compact = input.trim().replace(/[\s-]/g, '');
  const local = compact.startsWith('+86') || (compact.startsWith('86') && compact.length === 13) ?
    compact.replace(/^\+?86/, '') : compact;
  return /^1[0-9]{10}$/.test(local) ? '+86' + local : '';
}

function encodeForm(fields: Record<string, string>): string {
  return Object.keys(fields).map((name: string): string => {
    return name + '=' + encodeURIComponent(fields[name]).replace(/%20/g, '+');
  }).join('&');
}

function readReply(response: ZhihuHttpResponse): PhoneLoginReply {
  try {
    return (JSON.parse(response.text) as PhoneLoginReply) ?? {};
  } catch (error) {
    return {};
  }
}

function responseCode(reply: PhoneLoginReply): number {
  return Number(reply.error?.code ?? reply.code ?? 0);
}

function successful(response: ZhihuHttpResponse): boolean {
  return response.status >= 200 && response.status < 300;
}

function loginError(response: ZhihuHttpResponse, action: string): Error {
  if (response.status === 429) {
    return new Error('请求较频繁，请稍后重试');
  }
  if (response.status === 403 || (response.status >= 300 && response.status < 400)) {
    return new Error('知乎限制了当前手机号登录请求，请稍后重试');
  }
  return new Error(action + '失败（HTTP ' + response.status + '）');
}

export class ZhihuPhoneLogin {
  private readonly httpClient: ZhihuHttp = ZhihuHttp.getInstance();
  private readonly session: ZhihuSession = new ZhihuSession();
  private authorization: string = 'oauth ' + CLIENT_ID;
  private deviceId: string = '';
  private webDeviceCookie: string = '';
  private closed: boolean = false;

  public close(): void {
    this.closed = true;
    this.authorization = '';
    this.deviceId = '';
    this.webDeviceCookie = '';
  }

  private checkActive(): void {
    if (this.closed) {
      throw new Error('手机号登录已取消');
    }
  }

  private applyCookies(cookies?: Record<string, string>): void {
    if (cookies) {
      for (const name of Object.keys(cookies)) {
        const value = cookies[name];
        if (/^[\w.-]+$/.test(name) && typeof value === 'string' && value.trim() && !/[;\r\n\x00]/.test(value)) {
          this.session.applyCookieString(name + '=' + value);
        }
      }
    }
  }

  private async request(method: http.RequestMethod, path: string, form: string | null = null,
    extraHeaders: Record<string, string> = {}): Promise<ZhihuHttpResponse> {
    this.checkActive();
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'User-Agent': PHONE_LOGIN_UA,
      'Authorization': this.authorization,
      'x-api-version': '3.0.93',
      'x-app-version': '11.4.0',
      'x-app-build': 'release',
      'x-app-bundleid': CLIENT_SOURCE,
      'x-app-flavor': 'honor',
      'x-app-za': 'OS=Android&Release=12&Model=Android+SDK+built+for+arm64&VersionName=11.4.0&VersionCode=40408&' +
        'Product=com.zhihu.android&Width=1080&Height=2274&Installer=%E8%8D%A3%E8%80%80%E5%95%86%E5%BA%97&' +
        'DeviceType=AndroidPhone&Brand=Android',
      'x-network-type': '3G',
      'x-page-id': '44',
      'x-zse-93': '101_1_1.0'
    };
    for (const name of Object.keys(extraHeaders)) {
      headers[name] = extraHeaders[name];
    }
    if (this.deviceId) {
      headers['x-udid'] = this.deviceId;
    }
    const cookies = this.session.cookieHeader();
    if (cookies) {
      headers['Cookie'] = cookies;
    }
    if (form !== null) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    const response = await this.httpClient.requestForPhoneLogin(method, path, headers, this.session,
      form === null ? null : encryptPhoneLoginForm(form));
    this.checkActive();
    return response;
  }

  private async guestForm(): Promise<string> {
    const bundle = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return encodeForm({
      'app_build': '40408',
      'app_install_time': String(bundle.firstInstallTime ?? 0),
      'app_ticket': 'interface is empty',
      'app_version': '11.4.0',
      'bt_ck': '0',
      'bundle_id': CLIENT_SOURCE,
      'cp_ct': '0',
      'cp_tp': deviceInfo.abiList.split(',')[0],
      'cp_us': '0.0',
      'd_n': deviceInfo.productModel,
      'fr_mem': '0',
      'fr_st': '0',
      'latitude': '0.0',
      'longitude': '0.0',
      'nt_st': '0',
      'ph_br': deviceInfo.brand,
      'ph_md': deviceInfo.productModel,
      'ph_os': deviceInfo.osFullName,
      'pre_install': 'InterfaceIsNull',
      'tt_mem': '0',
      'tt_st': '0',
      'tz_of': String(-new Date().getTimezoneOffset() * 60),
      'zx_expired': '0'
    });
  }

  private async ensureGuestToken(): Promise<void> {
    this.checkActive();
    if (this.deviceId) {
      return;
    }
    if (!this.webDeviceCookie) {
      // Web account verification needs d_c0, but mobile guest initialization must use its own cookie jar.
      const webSession = new ZhihuSession();
      const response = await this.httpClient.requestForLogin(http.RequestMethod.POST, '/udid', webSession);
      this.checkActive();
      if (!successful(response) || !webSession.getDc0()) {
        throw loginError(response, '初始化知乎设备凭证');
      }
      this.webDeviceCookie = webSession.getDc0();
    }
    const form = await this.guestForm();
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature = await signPhoneLoginRequest(CLOUD_APP_SECRET, CLOUD_APP_ID + CLOUD_SIGN_VERSION + form + timestamp);
    const response = await this.request(http.RequestMethod.POST, GUEST_PATH, form, {
      'x-app-id': CLOUD_APP_ID,
      'x-sign-version': CLOUD_SIGN_VERSION,
      'x-req-ts': timestamp,
      'x-req-signature': signature
    });
    if (!successful(response)) {
      throw loginError(response, '初始化知乎访客会话');
    }
    const reply = readReply(response);
    const guest = reply.guest;
    if (typeof reply.udid !== 'string' || !reply.udid.trim() || /[\r\n]/.test(reply.udid) ||
      typeof guest?.access_token !== 'string' || !guest.access_token.trim() || /[\r\n]/.test(guest.access_token)) {
      throw new Error('知乎未返回可用的访客凭证');
    }
    this.applyCookies(guest.cookie);
    this.deviceId = reply.udid;
    this.authorization = 'bearer ' + guest.access_token;
  }

  private async needsCaptcha(): Promise<boolean> {
    const response = await this.request(http.RequestMethod.GET, CAPTCHA_PATH);
    if (!successful(response)) {
      throw loginError(response, '检查图形验证码');
    }
    const reply = readReply(response);
    if (typeof reply.show_captcha !== 'boolean') {
      throw new Error('知乎未返回图形验证码状态');
    }
    return reply.show_captcha;
  }

  public async refreshCaptcha(): Promise<string | undefined> {
    await this.ensureGuestToken();
    const response = await this.request(http.RequestMethod.PUT, CAPTCHA_PATH);
    if (!successful(response)) {
      throw loginError(response, '获取图形验证码');
    }
    const image = readReply(response).img_base64;
    return typeof image === 'string' && image.length > 0 ? image : undefined;
  }

  public async verifyCaptcha(input: string): Promise<boolean> {
    if (!input.trim()) {
      throw new Error('请输入图形验证码');
    }
    await this.ensureGuestToken();
    const response = await this.request(http.RequestMethod.POST, CAPTCHA_PATH, encodeForm({ 'input_text': input.trim() }));
    const reply = readReply(response);
    if ([120001, 120002].includes(responseCode(reply))) {
      return false;
    }
    if (!successful(response)) {
      throw loginError(response, '验证图形验证码');
    }
    return reply.success === true;
  }

  public async requestDigits(phoneNumber: string): Promise<ZhihuPhoneDigitsResult> {
    const username = normalizeZhihuPhoneNumber(phoneNumber);
    if (!username) {
      throw new Error('请输入正确的中国大陆手机号');
    }
    await this.ensureGuestToken();
    if (await this.needsCaptcha()) {
      return { captchaRequired: true, captchaImage: await this.refreshCaptcha() };
    }

    const form = encodeForm({ 'username': username, 'client_id': CLIENT_ID });
    let response = await this.request(http.RequestMethod.POST, DIGITS_PATH, form);
    if (responseCode(readReply(response)) === 120005) {
      if (await this.needsCaptcha()) {
        return { captchaRequired: true, captchaImage: await this.refreshCaptcha() };
      }
      response = await this.request(http.RequestMethod.POST, DIGITS_PATH, form);
    }
    const code = responseCode(readReply(response));
    if ([120001, 120002].includes(code)) {
      return { captchaRequired: true, captchaImage: await this.refreshCaptcha() };
    }
    if (!successful(response) || code) {
      throw loginError(response, '发送短信验证码');
    }
    return { captchaRequired: false };
  }

  public async signIn(phoneNumber: string, digits: string): Promise<string> {
    const username = normalizeZhihuPhoneNumber(phoneNumber);
    if (!username || !/^\d{6}$/.test(digits)) {
      throw new Error('请检查手机号和短信验证码');
    }
    await this.ensureGuestToken();
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature = await signPhoneLoginRequest(CLIENT_SECRET, 'digits' + CLIENT_ID + CLIENT_SOURCE + timestamp);
    const response = await this.request(http.RequestMethod.POST, SIGN_IN_PATH, encodeForm({
      'client_id': CLIENT_ID,
      'digits': digits,
      'grant_type': 'digits',
      'signature': signature,
      'source': CLIENT_SOURCE,
      'timestamp': timestamp,
      'username': username
    }));
    const reply = readReply(response);
    if (response.status === 400 || response.status === 401 || response.status === 422) {
      throw new Error('手机号或短信验证码无效，请核对后重试');
    }
    if (!successful(response) || responseCode(reply)) {
      throw loginError(response, '手机号登录');
    }
    if (typeof reply.access_token !== 'string' || !reply.access_token.trim()) {
      throw new Error('知乎未返回登录凭证');
    }
    this.applyCookies(reply.cookie);
    if (!this.session.getDc0()) {
      this.session.applyCookieString('d_c0=' + this.webDeviceCookie);
    }
    if (!this.session.isLoggedIn()) {
      throw new Error('知乎未返回可用的账号会话');
    }
    return this.session.cookieHeader();
  }
}
