import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';

export function loadReaderDocument(controller: webview.WebviewController, html: string): void {
  const bytes = new util.TextEncoder().encodeInto(html);
  const encoded = new util.Base64Helper().encodeToStringSync(bytes);
  controller.loadData(encoded, 'text/html;charset=UTF-8', 'base64');
}

export function updateReaderTopInset(controller: webview.WebviewController, inset: number): void {
  const value = JSON.stringify(inset + 'px');
  controller.runJavaScript('document.documentElement.style.setProperty("--reader-top-inset", ' + value + ')')
    .catch((): void => {});
}
