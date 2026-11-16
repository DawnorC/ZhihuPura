import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { pageTitleBar } from '../view/NavigationChrome';
import { ZhihuApi, ZhihuCollection, ZhihuFeedItem } from '@ohos/common';
import { FeedCard } from '../view/FeedCard';
import {
  APP_COLOR_BG, APP_COLOR_CARD, APP_COLOR_DIVIDER, APP_COLOR_SECONDARY, APP_COLOR_TEXT, openFeedItem
} from '../view/NavHelper';
import { EmptyView, ErrorView, LoadingView } from '../view/Widgets';

@Component
export struct CollectionsPage {
  private pathStack: NavPathStack = new NavPathStack();
  @StorageProp('zhihuLoggedIn') @Watch('accountChanged') loggedIn: boolean = false;
  @State title: string = '收藏夹';
  @State collections: ZhihuCollection[] = [];
  @State items: ZhihuFeedItem[] = [];
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State failed: boolean = false;
  @State moreFailed: boolean = false;
  @State hasMore: boolean = false;
  private collectionId: string = '';
  private nextUrl: string = '';
  private generation: number = 0;

  private accountChanged(): void {
    this.generation++;
    this.collections = [];
    this.items = [];
    this.nextUrl = '';
    this.hasMore = false;
    this.loadingMore = false;
    this.failed = false;
    this.moreFailed = false;
    if (this.loggedIn) {
      this.load(false);
    }
  }

  private async load(more: boolean): Promise<void> {
    const url = more ? this.nextUrl : '';
    if (!this.loggedIn || (more && (url.length === 0 || this.loading || this.loadingMore))) {
      return;
    }
    const generation = ++this.generation;
    const api = ZhihuApi.getInstance();
    this.loading = !more;
    this.loadingMore = more;
    this.failed = false;
    this.moreFailed = false;
    try {
      let next: string;
      if (this.collectionId.length === 0) {
        const page = await api.fetchCollections(url);
        if (generation !== this.generation) {
          return;
        }
        this.collections = more ? this.collections.concat(page.items) : page.items;
        next = page.nextUrl;
      } else {
        const page = await api.fetchCollectionItems(this.collectionId, url);
        if (generation !== this.generation) {
          return;
        }
        this.items = more ? this.items.concat(page.items) : page.items;
        next = page.isEnd ? '' : page.nextUrl;
      }
      this.nextUrl = next === url ? '' : next;
      this.hasMore = this.nextUrl.length > 0;
    } catch (error) {
      if (generation === this.generation) {
        this.failed = !more;
        this.moreFailed = more;
      }
    } finally {
      if (generation === this.generation) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  build() {
    HdsNavDestination() {
      if (!this.loggedIn) {
        Column({ space: 12 }) {
          Text('登录后可查看知乎收藏夹')
          Button('登录').onClick(() => this.pathStack.pushPathByName('login', ''))
        }
        .width('100%')
        .padding(24)
      } else if (this.loading) {
        LoadingView()
      } else if (this.failed) {
        ErrorView({ message: '无法加载收藏夹', onRetry: (): void => { this.load(false); } })
      } else if (this.collections.length === 0 && this.items.length === 0 && !this.hasMore) {
        EmptyView({ message: this.collectionId.length === 0 ? '还没有收藏夹' : '收藏夹里还没有可显示的内容' })
      } else {
        List() {
          ForEach(this.collections, (collection: ZhihuCollection) => {
            ListItem() {
              Column({ space: 6 }) {
                Text(collection.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(APP_COLOR_TEXT)
                if (collection.description.length > 0) {
                  Text(collection.description).fontSize(14).fontColor(APP_COLOR_SECONDARY).maxLines(2)
                }
                Text((collection.isPublic ? '公开' : '私密') + ' · ' + collection.count + ' 条内容')
                  .fontSize(12)
                  .fontColor(APP_COLOR_SECONDARY)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor(APP_COLOR_CARD)
              .onClick(() => { this.pathStack.pushPathByName('collections', collection); })
            }
          }, (collection: ZhihuCollection, index: number): string => collection.id + ':' + index)
          ForEach(this.items, (item: ZhihuFeedItem) => {
            ListItem() {
              FeedCard({
                item: item,
                onOpen: (opened: ZhihuFeedItem): void => { openFeedItem(this.pathStack, opened); }
              })
            }
          }, (item: ZhihuFeedItem, index: number): string => item.contentType + ':' + item.id + ':' + index)
          if (this.hasMore) {
            ListItem() {
              Button(this.loadingMore ? '加载中…' : (this.moreFailed ? '重试加载' : '加载更多'))
                .enabled(!this.loadingMore)
                .margin(12)
                .onClick(() => { this.load(true); })
            }
          }
        }
        .width('100%')
        .height('100%')
        .divider({ strokeWidth: 1, color: APP_COLOR_DIVIDER, startMargin: 16, endMargin: 16 })
      }
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar(this.title))
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      if (typeof context.pathInfo.param === 'object' && context.pathInfo.param !== null) {
        const collection = context.pathInfo.param as ZhihuCollection;
        this.collectionId = collection.id;
        this.title = collection.title;
      }
      this.accountChanged();
    })
  }
}

@Builder
export function CollectionsBuilder() {
  CollectionsPage()
}
