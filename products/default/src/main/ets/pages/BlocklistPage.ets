import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { pageTitleBar } from '../view/NavigationChrome';
/**
 * Blocklist management page, ported from the Android app's blocklist settings screen.
 */
import { BlockStore } from '@ohos/common';
import { APP_COLOR_BLUE, APP_COLOR_SECONDARY, APP_COLOR_TEXT, APP_COLOR_BG } from '../view/NavHelper';

@Component
export struct BlocklistPage {
  pathStack: NavPathStack = new NavPathStack();
  @State words: string[] = [];
  @State newWord: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.words = BlockStore.getInstance().getWords();
  }

  private addWord(): void {
    const word = this.newWord.trim();
    if (word.length === 0) {
      return;
    }
    BlockStore.getInstance().addWord(word)
      .then((): void => {
        this.newWord = '';
        this.refresh();
      })
      .catch((): void => {
        this.refresh();
      });
  }

  private removeWord(word: string): void {
    BlockStore.getInstance().removeWord(word)
      .then((): void => {
        this.refresh();
      })
      .catch((): void => {
        this.refresh();
      });
  }

  build() {
    HdsNavDestination() {
      Column() {
        Row({ space: 8 }) {
          TextInput({ placeholder: '输入屏蔽词（支持正则）', text: this.newWord })
            .fontSize(14)
            .height(38)
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .onChange((value: string) => {
              this.newWord = value;
            })
            .onSubmit(() => {
              this.addWord();
            })
          Button('添加')
            .fontSize(14)
            .height(38)
            .backgroundColor(APP_COLOR_BLUE)
            .onClick(() => {
              this.addWord();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        if (this.words.length === 0) {
          Column() {
            Text('还没有屏蔽词，添加后含该词的内容将不再显示')
              .fontSize(13)
              .fontColor(APP_COLOR_SECONDARY)
          }
          .width('100%')
          .padding(40)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.words, (word: string, index: number) => {
              ListItem() {
                Row() {
                  Text(word)
                    .fontSize(15)
                    .fontColor(APP_COLOR_TEXT)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(13)
                    .fontColor('#EC4141')
                    .padding({ left: 12, right: 4, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.removeWord(word);
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 13, bottom: 13 })
                .backgroundColor('#FFFFFF')
              }
            }, (word: string, index: number): string => word + '_' + index)
          }
          .width('100%')
          .height('100%')
          .backgroundColor(APP_COLOR_BG)
          .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 16, endMargin: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(APP_COLOR_BG)
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(pageTitleBar('屏蔽词管理'))
    .backgroundColor(APP_COLOR_BG)
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}

@Builder
export function BlocklistBuilder() {
  BlocklistPage()
}
