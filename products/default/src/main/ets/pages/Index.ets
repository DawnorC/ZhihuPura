/**
 * Main entry: Navigation host with 5 tabs (首页 / 关注 / 热榜 / 日报 / 我的),
 * ported from MainScreen.kt bottom-navigation structure.
 */
import { BlockStore, encryptZseV4, ZhihuApi, ZhihuFeedPage, ZhihuHttp, ZhihuSession } from '@ohos/common';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedListTab } from '../view/FeedListTab';
import { HotListTab } from '../view/HotListTab';
import { DailyTab } from '../view/DailyTab';
import { MineTab } from '../view/MineTab';
import { syncCookiesToWebView, APP_COLOR_BG, APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT } from '../view/NavHelper';

const TAB_TITLES: string[] = ['首页', '关注', '热榜', '日报', '我的'];

@Entry
@Component
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @State currentTab: number = 0;

  aboutToAppear(): void {
    const context = getContext(this);
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
        // preferences init failure: continue with in-memory session
      });
  }

  build() {
    Navigation(this.pathStack) {
      Column() {
        Tabs({ index: this.currentTab }) {
          TabContent() {
            FeedListTab({
              pathStack: this.pathStack,
              headerTitle: '首页',
              showSearchEntry: true,
              fetcher: (url: string): Promise<ZhihuFeedPage> =>
                ZhihuApi.getInstance().fetchRecommend(url.length > 0 ? url : null)
            })
          }
          .tabBar('首页')

          TabContent() {
            FeedListTab({
              pathStack: this.pathStack,
              headerTitle: '关注',
              loginRequired: true,
              emptyText: '关注的人还没有新动态',
              fetcher: (url: string): Promise<ZhihuFeedPage> =>
                ZhihuApi.getInstance().fetchFollowFeed(url.length > 0 ? url : null)
            })
          }
          .tabBar('关注')

          TabContent() {
            HotListTab({ pathStack: this.pathStack })
          }
          .tabBar('热榜')

          TabContent() {
            DailyTab({ pathStack: this.pathStack })
          }
          .tabBar('日报')

          TabContent() {
            MineTab({ pathStack: this.pathStack })
          }
          .tabBar('我的')
        }
        .barHeight(0)
        .layoutWeight(1)
        .width('100%')
        .onChange((index: number) => {
          this.currentTab = index;
        })

        Divider()
          .color('#E8E8E8')
          .strokeWidth(0.5)

        Row() {
          ForEach(TAB_TITLES, (title: string, index: number) => {
            Column({ space: 3 }) {
              Circle({ width: 20, height: 20 })
                .fill(this.currentTab === index ? APP_COLOR_BLUE : '#C9CED6')
              Text(title)
                .fontSize(11)
                .fontColor(this.currentTab === index ? APP_COLOR_TEXT : APP_COLOR_SECONDARY)
                .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .padding({ top: 6, bottom: 6 })
            .onClick(() => {
              this.currentTab = index;
            })
          }, (title: string, index: number): string => title + '_' + index)
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .backgroundColor(APP_COLOR_BG)
  }
}
