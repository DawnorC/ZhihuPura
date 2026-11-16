import { FLOATING_BAR_CLEARANCE, MINI_TITLE_BAR_HEIGHT } from './NavigationChrome';
/**
 * Account tab, ported from AccountScreen (账号页): login entry, blocklist, about, logout.
 */
import { ZhihuSession, ZhihuApi, ZhihuHttpError } from '@ohos/common';
import { preferences } from '@kit.ArkData';
import { clearZhihuWebLogin, showToast } from './NavHelper';
import { APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_BG } from './NavHelper';

@Component
export struct MineTab {
  pathStack: NavPathStack = new NavPathStack();
  scroller: Scroller = new Scroller();
  @Prop titleInset: number = MINI_TITLE_BAR_HEIGHT;
  @StorageProp('floatingBottomBar') floatingBottomBar: boolean = false;
  @State savingBottomBar: boolean = false;
  @StorageProp('zhihuLoggedIn') loggedIn: boolean = false;
  @StorageProp('zhihuUserName') userName: string = '';
  @StorageProp('zhihuUserAvatar') userAvatar: string = '';

  private async doLogout(): Promise<void> {
    const session = ZhihuSession.getInstance();
    await session.logout();
    clearZhihuWebLogin();
    AppStorage.setOrCreate('zhihuLoggedIn', false);
    AppStorage.setOrCreate('zhihuUserName', '');
    AppStorage.setOrCreate('zhihuUserAvatar', '');
    showToast(this.getUIContext(), '已退出登录');
  }

  private async setFloatingBottomBar(enabled: boolean): Promise<void> {
    if (this.savingBottomBar) {
      return;
    }
    this.savingBottomBar = true;
    try {
      const store = await preferences.getPreferences(getContext(this), 'zhihu_appearance');
      await store.put('floatingBottomBar', enabled);
      await store.flush();
      AppStorage.setOrCreate('floatingBottomBar', enabled);
    } catch (error) {
      showToast(this.getUIContext(), '底栏设置保存失败');
    } finally {
      this.savingBottomBar = false;
    }
  }

  build() {
    Column() {

      Scroll(this.scroller) {
        Column() {
          Row({ space: 14 }) {
            if (this.userAvatar.length > 0) {
              Image(this.userAvatar)
                .width(56)
                .height(56)
                .borderRadius(28)
                .backgroundColor('#EEEEEE')
            } else {
              Circle({ width: 56, height: 56 })
                .fill('#DDDDDD')
            }
            Column({ space: 4 }) {
              Text(this.loggedIn && this.userName.length > 0 ? this.userName : '未登录')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(APP_COLOR_TEXT)
              Text(this.loggedIn ? '知乎用户 · 知乎Pura' : '登录知乎账号，同步你的关注与数据')
                .fontSize(13)
                .fontColor(APP_COLOR_SECONDARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (!this.loggedIn) {
              Button('登录')
                .fontSize(14)
                .height(34)
                .backgroundColor(APP_COLOR_BLUE)
                .onClick(() => {
                  this.pathStack.pushPathByName('login', '');
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 12, right: 12, top: 12 })
          .onClick(() => {
            if (!this.loggedIn) {
              this.pathStack.pushPathByName('login', '');
            }
          })

          Column() {
            Row() {
              Text('悬浮玻璃底栏').fontSize(15).fontColor(APP_COLOR_TEXT).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.floatingBottomBar })
                .enabled(!this.savingBottomBar)
                .onChange((enabled: boolean) => { this.setFloatingBottomBar(enabled); })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            Divider().color('#F0F0F0').margin({ left: 16 })
            this.menuItem('收藏夹', (): void => {
              this.pathStack.pushPathByName('collections', '');
            })
            Divider().color('#F0F0F0').margin({ left: 16 })
            this.menuItem('浏览历史', (): void => {
              this.pathStack.pushPathByName('history', '');
            })
            Divider().color('#F0F0F0').margin({ left: 16 })
            this.menuItem('屏蔽词管理', (): void => {
              this.pathStack.pushPathByName('blocklist', '');
            })
            Divider().color('#F0F0F0').margin({ left: 16 })
            this.menuItem('刷新账号信息', (): void => {
              if (!this.loggedIn) {
                showToast(this.getUIContext(), '请先登录');
                return;
              }
              ZhihuApi.getInstance().refreshMe()
                .then((): void => {
                  const session = ZhihuSession.getInstance();
                  AppStorage.setOrCreate('zhihuUserName', session.user.name);
                  AppStorage.setOrCreate('zhihuUserAvatar', session.user.avatarUrl);
                  showToast(this.getUIContext(), '已更新账号信息');
                })
                .catch((error: ZhihuHttpError): void => {
                  showToast(this.getUIContext(), '更新失败：' + error.message);
                });
            })
            Divider().color('#F0F0F0').margin({ left: 16 })
            this.menuItem('关于知乎Pura', (): void => {
              this.showAbout();
            })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 12, right: 12, top: 12 })

          if (this.loggedIn) {
            Button('退出登录')
              .fontSize(15)
              .fontColor('#EC4141')
              .height(44)
              .width('90%')
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .margin({ top: 12 })
              .onClick(() => {
                this.doLogout();
              })
          }
        }
        .width('100%')
        .padding({ top: this.titleInset, bottom: this.floatingBottomBar ? FLOATING_BAR_CLEARANCE : 12 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.BOTTOM] : [])
      .scrollBar(BarState.Off)
      .backgroundColor(APP_COLOR_BG)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.BOTTOM] : [])
    .backgroundColor(APP_COLOR_BG)
  }

  @Builder
  menuItem(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(APP_COLOR_TEXT)
      Blank()
      Text('>')
        .fontSize(15)
        .fontColor(APP_COLOR_SECONDARY)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      action();
    })
  }

  private showAbout(): void {
    AlertDialog.show({
      title: '关于知乎Pura',
      message: '知乎Pura v1.0.0\n\n移植自开源项目 Zhihu++（zhihu-plus-plus），' +
        '注重隐私、无广告的第三方知乎客户端。\n\n原项目遵循 AGPL-3.0 许可证，' +
        'Copyright (C) 2024-2026 zly2006。',
      confirm: {
        value: '确定',
        action: (): void => {
        }
      }
    });
  }
}
