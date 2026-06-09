import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    if (want.parameters && want.parameters['total'] !== undefined) {
      AppStorage.setOrCreate('total', want.parameters['total']);
      AppStorage.setOrCreate('records', want.parameters['records']);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    try {
      windowStage.loadContent('pages/Index', (err, data) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: ' + JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in loading the content. Data: ' + JSON.stringify(data));
      });
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: ' + JSON.stringify(error));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    hilog.info(DOMAIN, TAG, 'Ability onContinue');
    wantParam['total'] = AppStorage.get<number>('total') || 0;
    wantParam['records'] = AppStorage.get<string>('records') || '[]';
    return AbilityConstant.OnContinueResult.AGREE;
  }
}