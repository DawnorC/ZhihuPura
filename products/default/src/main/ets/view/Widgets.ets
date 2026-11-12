/**
 * Shared UI widgets: loading / error / empty states.
 */
import { APP_COLOR_BLUE, APP_COLOR_SECONDARY } from './NavHelper';

@Component
export struct LoadingView {
  label: string = '加载中…';

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(APP_COLOR_BLUE)
      Text(this.label)
        .fontSize(14)
        .fontColor(APP_COLOR_SECONDARY)
    }
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct ErrorView {
  @Prop message: string = '加载失败';
  onRetry: () => void = (): void => {
  };

  build() {
    Column({ space: 12 }) {
      Text('加载失败')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text(this.message)
        .fontSize(13)
        .fontColor(APP_COLOR_SECONDARY)
        .maxLines(3)
        .textAlign(TextAlign.Center)
      Button('重试')
        .fontSize(14)
        .height(36)
        .backgroundColor(APP_COLOR_BLUE)
        .onClick(() => {
          this.onRetry();
        })
    }
    .width('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct EmptyView {
  message: string = '这里什么都没有';

  build() {
    Column() {
      Text(this.message)
        .fontSize(14)
        .fontColor(APP_COLOR_SECONDARY)
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
  }
}
