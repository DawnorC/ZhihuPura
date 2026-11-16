/**
 * Main entry: Navigation host with 5 tabs (首页 / 关注 / 热榜 / 日报 / 我的),
 * ported from MainScreen.kt bottom-navigation structure.
 */
import { BlockStore, encryptZseV4, ZhihuApi, ZhihuFeedPage, ZhihuHttp, ZhihuSession } from '@ohos/common';
import { SymbolGlyphModifier, window } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, HideMode } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { FeedListTab } from '../view/FeedListTab';
import { HotListTab } from '../view/HotListTab';
import { DailyTab } from '../view/DailyTab';
import { MineTab } from '../view/MineTab';
import { createGlassMaterial, MINI_TITLE_BAR_HEIGHT, spatialTitleBar } from '../view/NavigationChrome';
import { syncCookiesToWebView, APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_SECONDARY } from '../view/NavHelper';

const TAB_TITLES: string[] = ['首页', '关注', '热榜', '日报', '我的'];
const TAB_ICONS: Resource[] = [
  $r('sys.symbol.house'), $r('sys.symbol.heart'), $r('sys.symbol.flame'),
  $r('sys.symbol.doc_text'), $r('sys.symbol.person')
];
const TAB_SELECTED_ICONS: Resource[] = [
  $r('sys.symbol.house_fill'), $r('sys.symbol.heart_fill'), $r('sys.symbol.flame_fill'),
  $r('sys.symbol.doc_text_fill'), $r('sys.symbol.person_fill')
];

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @StorageLink('statusBarHeightPx') private statusBarHeightPx: number = 0;
  @StorageLink('bottomSafeAreaPx') private bottomSafeAreaPx: number = 0;
  @State currentTab: number = 0;
  @StorageProp('floatingBottomBar') floatingBottomBar: boolean = false;
  @State refreshTab: number = -1;
  @State refreshRequest: number = 0;
  @State private feedSessionReady: boolean = false;
  private tabScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller(), new Scroller()];
  private readonly dockMaterial = createGlassMaterial();
  private mainWindow?: window.Window;
  private readonly onAvoidAreaChange = (options: window.AvoidAreaOptions): void => {
    if (options.type === window.AvoidAreaType.TYPE_SYSTEM || options.type === window.AvoidAreaType.TYPE_CUTOUT ||
      options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      this.updateWindowInsets();
    }
  };

  private getTitleInset(): number {
    return MINI_TITLE_BAR_HEIGHT + this.getUIContext().px2vp(this.statusBarHeightPx);
  }

  private updateWindowInsets(): void {
    const mainWindow = this.mainWindow;
    if (mainWindow === undefined) {
      return;
    }
    const system = mainWindow.getWindowAvoidAreaIgnoringVisibility(window.AvoidAreaType.TYPE_SYSTEM);
    const cutout = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
    const navigation = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    this.statusBarHeightPx = Math.max(system.topRect.height, cutout.topRect.height);
    this.bottomSafeAreaPx = Math.max(system.bottomRect.height, cutout.bottomRect.height, navigation.bottomRect.height);
  }

  aboutToAppear(): void {
    const context = getContext(this);
    window.getLastWindow(context).then((mainWindow: window.Window): void => {
      this.mainWindow = mainWindow;
      this.updateWindowInsets();
      mainWindow.on('avoidAreaChange', this.onAvoidAreaChange);
    }).catch((error: Error): void => {
      hilog.warn(0x0000, 'ZhihuPura', 'Unable to read window insets: %{public}s', error.message);
    });
    preferences.getPreferences(context, 'zhihu_appearance')
      .then((store: preferences.Preferences): Promise<preferences.ValueType> => store.get('floatingBottomBar', false))
      .then((enabled: preferences.ValueType): void => {
        AppStorage.setOrCreate('floatingBottomBar', enabled === true);
      })
      .catch((): void => {});
    hilog.info(0x0000, 'ZseSign', 'zse-hello=%{public}s', encryptZseV4('hello'));
    ZhihuSession.getInstance().init(context)
      .then((): Promise<void> => BlockStore.getInstance().init(context))
      .then((): void => {
        const session = ZhihuSession.getInstance();
        AppStorage.setOrCreate('zhihuLoggedIn', session.isLoggedIn());
        AppStorage.setOrCreate('zhihuUserName', session.user.name);
        AppStorage.setOrCreate('zhihuUserAvatar', session.user.avatarUrl);
        syncCookiesToWebView();
        ZhihuHttp.getInstance().ensureDevice()
          .then((): void => {
            syncCookiesToWebView();
          })
          .catch((): void => {
            // device warm-up is best-effort; requests retry lazily
          });
      })
      .catch((): void => {
        // Preferences may be unavailable; allow feeds to use the in-memory session.
      })
      .finally((): void => {
        this.feedSessionReady = true;
      });
  }

  aboutToDisappear(): void {
    this.mainWindow?.off('avoidAreaChange', this.onAvoidAreaChange);
    this.mainWindow = undefined;
  }

  private selectTab(index: number): void {
    if (this.currentTab !== index) {
      this.currentTab = index;
      return;
    }
    const scroller = this.tabScrollers[index];
    const offset = scroller.offset();
    if (offset !== undefined && offset.yOffset > 1) {
      scroller.scrollEdge(Edge.Top);
    } else if (index < TAB_TITLES.length - 1) {
      this.refreshTab = index;
      this.refreshRequest++;
    }
  }

  @Builder
  bottomBar(native: boolean = false) {
    Row() {
      ForEach(TAB_TITLES, (title: string, index: number) => {
        Column({ space: 3 }) {
          SymbolGlyph(this.currentTab === index ? TAB_SELECTED_ICONS[index] : TAB_ICONS[index])
            .fontSize(22)
            .fontColor([this.currentTab === index ? APP_COLOR_BLUE : APP_COLOR_SECONDARY])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            .accessibilityLevel('no')
          Text(title)
            .fontSize(11)
            .fontColor(this.currentTab === index ? APP_COLOR_BLUE : APP_COLOR_SECONDARY)
            .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        }
        .layoutWeight(1)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .borderRadius(24)
        .backgroundColor(this.floatingBottomBar && !native && this.currentTab === index ? '#180066FF' : Color.Transparent)
        .onClick(() => { this.selectTab(index); })
      }, (title: string): string => title)
    }
    .height(56)
    .width(native ? '100%' : (this.floatingBottomBar ? '90%' : '100%'))
    .constraintSize({ maxWidth: this.floatingBottomBar ? 420 : '100%' })
    .padding({ left: this.floatingBottomBar ? 5 : 0, right: this.floatingBottomBar ? 5 : 0 })
    .borderRadius(this.floatingBottomBar ? 28 : 0)
    .backgroundColor(native ? Color.Transparent : (this.floatingBottomBar ? '#BFF5F6F8' : '#FFFFFF'))
    .systemMaterial(native ? this.dockMaterial : undefined)
    .backdropBlur(this.floatingBottomBar && !native ? 24 : 0)
    .border({ width: this.floatingBottomBar && !native ? 1 : 0, color: '#E6FFFFFF' })
    .shadow({
      radius: this.floatingBottomBar && !native ? 14 : 0, color: '#261C3555',
      offsetY: this.floatingBottomBar ? 4 : 0
    })
  }

  build() {
    HdsNavigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(APP_COLOR_CARD)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.None)
        Column() {
        Tabs({ index: this.currentTab }) {
          TabContent() {
            FeedListTab({
              pathStack: this.pathStack,
              scroller: this.tabScrollers[0],
              titleInset: this.getTitleInset(),
              sessionReady: this.feedSessionReady,
              refreshRequest: this.refreshTab === 0 ? this.refreshRequest : 0,
              fetcher: (url: string): Promise<ZhihuFeedPage> =>
                ZhihuApi.getInstance().fetchRecommend(url.length > 0 ? url : null)
            })
          }
          .tabBar('首页')

          TabContent() {
            FeedListTab({
              pathStack: this.pathStack,
              scroller: this.tabScrollers[1],
              titleInset: this.getTitleInset(),
              sessionReady: this.feedSessionReady,
              refreshRequest: this.refreshTab === 1 ? this.refreshRequest : 0,
              loginRequired: true,
              emptyText: '关注的人还没有新动态',
              fetcher: (url: string): Promise<ZhihuFeedPage> =>
                ZhihuApi.getInstance().fetchFollowFeed(url.length > 0 ? url : null)
            })
          }
          .tabBar('关注')

          TabContent() {
            HotListTab({
              pathStack: this.pathStack, scroller: this.tabScrollers[2], titleInset: this.getTitleInset(),
              refreshRequest: this.refreshTab === 2 ? this.refreshRequest : 0
            })
          }
          .tabBar('热榜')

          TabContent() {
            DailyTab({
              pathStack: this.pathStack, scroller: this.tabScrollers[3], titleInset: this.getTitleInset(),
              refreshRequest: this.refreshTab === 3 ? this.refreshRequest : 0
            })
          }
          .tabBar('日报')

          TabContent() {
            MineTab({ pathStack: this.pathStack, scroller: this.tabScrollers[4], titleInset: this.getTitleInset() })
          }
          .tabBar('我的')
        }
        .clip(false)
        .barHeight(0)
        .layoutWeight(1)
        .width('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], this.floatingBottomBar ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.TOP])
        .onChange((index: number) => {
          this.currentTab = index;
        })

        if (!this.floatingBottomBar) {
          Divider().color('#E8E8E8').strokeWidth(0.5)
          this.bottomBar()
        }
        }
        .width('100%')
        .height(LayoutPolicy.matchParent)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], this.floatingBottomBar ? [LayoutSafeAreaEdge.BOTTOM] : [])

        if (this.floatingBottomBar) {
          Column() {
            if (this.dockMaterial !== undefined) {
              Tabs({ barPosition: BarPosition.End }) {
                TabContent().tabBar(this.bottomBar(true))
              }
              .width('90%')
              .constraintSize({ maxWidth: 420 })
              .height(56)
              .barHeight(56)
              .scrollable(false)
              .divider(null)
              .barBackgroundColor(Color.Transparent)
              .barBackgroundBlurStyle(BlurStyle.NONE)
              .backgroundColor(Color.Transparent)
              .clip(false)
              .hitTestBehavior(HitTestMode.None)
            } else {
              this.bottomBar()
            }
          }
          .width('100%')
          .padding({ bottom: 8 })
          .position({ bottom: 0, left: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .height(LayoutPolicy.matchParent)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .dynamicHideTitleBar({ hideTitleArea: true, mode: HideMode.SCROLL_UP })
    .titleBar(spatialTitleBar({
      title: { mainTitle: TAB_TITLES[this.currentTab] },
      menu: {
        value: this.currentTab === 0 ? [{
          content: {
            icon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')),
            label: '搜索',
            action: (): void => { this.pathStack.pushPathByName('search', ''); }
          }
        }] : []
      }
    }, this.getTitleInset()))
    .bindToScrollable([this.tabScrollers[this.currentTab]])
    .mode(NavigationMode.Stack)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(APP_COLOR_CARD)
  }
}
