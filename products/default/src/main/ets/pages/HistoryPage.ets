import { HistoryEntry, HistoryStore, formatRelativeTime } from '@ohos/common';
import {
  APP_COLOR_BG, APP_COLOR_BLUE, APP_COLOR_CARD, APP_COLOR_DIVIDER, APP_COLOR_SECONDARY, APP_COLOR_TEXT,
  ContentPageParam, DailyStoryPageParam, QuestionPageParam, showToast
} from '../view/NavHelper';
import { EmptyView, ErrorView, LoadingView } from '../view/Widgets';

@Component
export struct HistoryPage {
  private pathStack: NavPathStack = new NavPathStack();
  @State entries: HistoryEntry[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;

  private async refresh(): Promise<void> {
    try {
      this.entries = await HistoryStore.getInstance().list(getContext(this));
      this.failed = false;
    } catch (error) {
      this.failed = true;
    } finally {
      this.loading = false;
    }
  }

  private async remove(entry: HistoryEntry): Promise<void> {
    try {
      await HistoryStore.getInstance().remove(getContext(this), entry);
      await this.refresh();
    } catch (error) {
      showToast(this.getUIContext(), '删除历史记录失败');
    }
  }

  private label(kind: string): string {
    switch (kind) {
      case 'answer': return '回答';
      case 'article': return '文章';
      case 'pin': return '想法';
      case 'question': return '问题';
      case 'daily': return '日报';
      default: return '知乎内容';
    }
  }

  private open(entry: HistoryEntry): void {
    if (entry.kind === 'question') {
      const param: QuestionPageParam = { id: entry.id };
      this.pathStack.pushPathByName('question', param);
    } else if (entry.kind === 'daily') {
      const param: DailyStoryPageParam = { id: entry.id };
      this.pathStack.pushPathByName('dailystory', param);
    } else {
      const param: ContentPageParam = { kind: entry.kind, id: entry.id, title: entry.title };
      this.pathStack.pushPathByName('content', param);
    }
  }

  build() {
    NavDestination() {
      if (this.loading) {
        LoadingView()
      } else if (this.failed) {
        ErrorView({ message: '无法读取浏览历史', onRetry: (): void => { this.refresh(); } })
      } else if (this.entries.length === 0) {
        EmptyView({ message: '还没有浏览历史' })
      } else {
        List() {
          ForEach(this.entries, (entry: HistoryEntry) => {
            ListItem() {
              Row({ space: 12 }) {
                Column({ space: 5 }) {
                  Text(entry.title.trim().length > 0 ? entry.title : this.label(entry.kind))
                    .fontSize(16)
                    .fontColor(APP_COLOR_TEXT)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.label(entry.kind) + ' · ' + formatRelativeTime(entry.viewedAt))
                    .fontSize(12)
                    .fontColor(APP_COLOR_SECONDARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => this.open(entry))

                Button('删除', { type: ButtonType.Normal })
                  .fontSize(13)
                  .fontColor(APP_COLOR_BLUE)
                  .backgroundColor(Color.Transparent)
                  .height(44)
                  .onClick(() => { this.remove(entry); })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 8, bottom: 8 })
              .backgroundColor(APP_COLOR_CARD)
            }
          }, (entry: HistoryEntry): string => entry.kind + ':' + entry.id + ':' + entry.viewedAt)
        }
        .width('100%')
        .height('100%')
        .divider({ strokeWidth: 1, color: APP_COLOR_DIVIDER, startMargin: 16, endMargin: 16 })
      }
    }
    .title('浏览历史')
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
    .onShown(() => { this.refresh(); })
  }
}

@Builder
export function HistoryBuilder() {
  HistoryPage()
}
