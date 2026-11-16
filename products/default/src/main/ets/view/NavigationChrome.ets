import { ColorMetrics, LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleBarStyle,
  ScrollEffectType,
  TitleBarContentOptions
} from '@kit.UIDesignKit';

export const MINI_TITLE_BAR_HEIGHT: number = 56;
export const FLOATING_BAR_CLEARANCE: number = 68;

export function createGlassMaterial(): uiMaterial.ImmersiveMaterial | undefined {
  try {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: '#55FFFFFF',
      interactive: false,
      applyShadow: false,
      lightEffect: null
    });
  } catch (error) {
    return undefined;
  }
}

export function spatialTitleBar(content: TitleBarContentOptions, topInset?: number,
  webScrollOffset?: number): HdsNavigationTitleBarOptions {
  const scrollDistance = topInset ?? MINI_TITLE_BAR_HEIGHT;
  // Keep the title readable when the first line starts to scroll behind it.
  let originalStyle: HdsNavigationTitleBarStyle | undefined =
    topInset === undefined ? undefined : { backgroundStyle: { blurRadius: 8 } };
  // Web owns its scroll position and cannot supply a Scroller to HDS.
  if (webScrollOffset !== undefined) {
    const progress = Math.min(1, Math.max(0, webScrollOffset / scrollDistance));
    const gray = ColorMetrics.resourceColor($r('sys.color.comp_background_gray'));
    originalStyle = {
      backgroundStyle: {
        backgroundColor: ColorMetrics.rgba(gray.red, gray.green, gray.blue, progress * gray.alpha / 255).color,
        blurRadius: 12 * progress
      }
    };
  }
  return {
    content,
    enableComponentSafeArea: true,
    style: {
      scrollEffectOpts: {
        enableScrollEffect: webScrollOffset === undefined,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        enableRefreshOffsetChange: false,
        blurEffectiveEndOffset: LengthMetrics.vp(scrollDistance)
      },
      originalStyle,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    }
  };
}

export function pageTitleBar(title: ResourceStr, topInset?: number, webScrollOffset?: number): HdsNavigationTitleBarOptions {
  return spatialTitleBar({ title: { mainTitle: title } }, topInset, webScrollOffset);
}
