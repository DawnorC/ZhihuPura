import { OnlineHistoryEntry, ZhihuApi, ZhihuContentType, ZhihuSession } from '@ohos/common';
import {
  APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_DIVIDER, APP_COLOR_TEXT, openFeedItem, showToast
} from './NavHelper';
import { EmptyView, ErrorView, LoadingView } from './Widgets';

@Component
export struct OnlineHistoryList {
  pathStack: NavPathStack = new NavPathStack();
  @StorageProp('zhihuLoggedIn') @Watch('accountChanged') loggedIn: boolean = false;
  @State entries: OnlineHistoryEntry[] = [];
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State failure: string = '';
  @State moreFailed: boolean = false;
  @State deleting: boolean = false;
  private nextUrl: string = '';
  private generation: number = 0;

  aboutToAppear(): void {
    this.accountChanged();
  }

  private accountChanged(): void {
    this.generation++;
    this.entries = [];
    this.nextUrl = '';
    this.failure = '';
    this.loadingMore = false;
    this.moreFailed = false;
    if (this.loggedIn) {
      this.fetch(false);
    }
  }

  private async fetch(more: boolean): Promise<void> {
    const url = more ? this.nextUrl : '';
    if (!this.loggedIn || (more && (url.length === 0 || this.loading || this.loadingMore || this.deleting))) {
      return;
    }
    const generation = ++this.generation;
    this.loading = !more;
    this.loadingMore = more;
    this.failure = '';
    this.moreFailed = false;
    try {
      const page = await ZhihuApi.getInstance().fetchOnlineHistory(url);
      if (generation === this.generation) {
        this.entries = more ? this.entries.concat(page.entries) : page.entries;
        this.nextUrl = page.nextUrl === url ? '' : page.nextUrl;
      }
    } catch (error) {
      if (generation === this.generation) {
        if (more) {
          this.moreFailed = true;
        } else {
          this.failure = '在线历史加载失败，请确认知乎账号仍处于登录状态';
        }
      }
    } finally {
      if (generation === this.generation) {
        this.loading = false;
        this.loadingMore = false;
      }
    }
  }

  private async remove(entry: OnlineHistoryEntry): Promise<void> {
    if (this.deleting || !this.loggedIn || !ZhihuSession.getInstance().isLoggedIn()) {
      return;
    }
    this.deleting = true;
    try {
      await ZhihuApi.getInstance().deleteOnlineHistory(entry);
      await this.fetch(false);
    } catch (error) {
      showToast(this.getUIContext(), '删除在线历史失败');
    } finally {
      this.deleting = false;
    }
  }

  build() {
    if (!this.loggedIn) {
      Column({ space: 12 }) {
        Text('登录后可查看知乎在线历史')
        Button('登录').onClick(() => this.pathStack.pushPathByName('login', ''))
      }
      .width('100%')
      .padding(24)
    } else if (this.loading) {
      LoadingView()
    } else if (this.failure.length > 0) {
      ErrorView({ message: this.failure, onRetry: (): void => { this.fetch(false); } })
    } else if (this.entries.length === 0 && this.nextUrl.length === 0) {
      EmptyView({ message: '还没有在线浏览历史' })
    } else {
      List() {
        ForEach(this.entries, (entry: OnlineHistoryEntry) => {
          ListItem() {
            Row({ space: 12 }) {
              Text(entry.item.title)
                .fontSize(16)
                .fontColor(APP_COLOR_TEXT)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  if (entry.item.contentType === ZhihuContentType.Unknown) {
                    showToast(this.getUIContext(), '此内容类型暂不支持打开');
                  } else {
                    openFeedItem(this.pathStack, entry.item);
                  }
                })
              if (entry.contentToken.length > 0 && entry.contentType.length > 0) {
                Button('删除', { type: ButtonType.Normal })
                  .fontSize(13)
                  .fontColor(APP_COLOR_BLUE)
                  .backgroundColor(Color.Transparent)
                  .height(44)
                  .enabled(!this.deleting && !this.loadingMore)
                  .onClick(() => {
                    this.getUIContext().showAlertDialog({
                      title: '删除在线浏览记录？',
                      message: '这条记录将从知乎账号的浏览历史中删除。',
                      primaryButton: { value: '取消', action: (): void => {} },
                      secondaryButton: { value: '删除', action: (): void => { this.remove(entry); } }
                    });
                  })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 12, top: 8, bottom: 8 })
            .backgroundColor(APP_COLOR_CARD)
          }
        }, (entry: OnlineHistoryEntry, index: number): string => entry.contentToken + ':' + index)
        if (this.nextUrl.length > 0) {
          ListItem() {
            Button(this.loadingMore ? '加载中…' : (this.moreFailed ? '重试加载' : '加载更多'))
              .enabled(!this.loadingMore && !this.deleting)
              .margin(12)
              .onClick(() => { this.fetch(true); })
          }
        }
      }
      .width('100%')
      .height('100%')
      .divider({ strokeWidth: 1, color: APP_COLOR_DIVIDER, startMargin: 16, endMargin: 16 })
    }
  }
}
