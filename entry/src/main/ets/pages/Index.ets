import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import window from '@ohos.window';

// 1. 原有接口（新增 category 和 date 字段）
interface BillRecord {
  type: string;
  category: string;
  money: number;
  note: string;
  date: string;
}

// 2. 类别数据
const EXPENSE_CATEGORIES: string[] = [
  '时尚', '三餐', '零食', '酒水', '生活', '旅游', '医疗', '娱乐', '交通', '日常', '人情'
];

const INCOME_CATEGORIES: string[] = [
  '职业收入', '投资回报', '退款', '人情', '其他收入'
];

@Entry
@Component
struct Index {
  // 原有状态
  @State money: string = '';
  @State note: string = '';
  @State isIncome: boolean = true;
  @State total: number = 0;
  @State records: BillRecord[] = [];

  // 新增类别选择状态
  @State selectedCategoryIndex: number = 0;
  @State selectedDate: string = new Date().toISOString().split('T')[0];
  @State currentBreakpoint: string = 'SM';

  private dataPreferences: preferences.Preferences | null = null;

  // 初始化数据存储
  async initPreferences() {
    try {
      this.dataPreferences = await preferences.getPreferences(getContext(), 'bill_data');
      const totalStr = await this.dataPreferences.get('total', '0') as string;
      this.total = parseFloat(totalStr);
      const recordsStr = await this.dataPreferences.get('records', '[]') as string;
      this.records = JSON.parse(recordsStr);
    } catch (e) {
      console.error('加载数据失败', e);
    }
  }

  // 保存数据
  async saveData() {
    try {
      if (this.dataPreferences) {
        await this.dataPreferences.put('total', this.total.toString());
        await this.dataPreferences.put('records', JSON.stringify(this.records));
        await this.dataPreferences.flush();
      }
    } catch (e) {
      console.error('保存数据失败', e);
    }
  }

  aboutToAppear() {
    this.initPreferences();
    try {
      window.getLastWindow(getContext()).then((win) => {
        const updateBreakpoint = () => {
          const rect = win.getWindowProperties().windowRect;
          const width = rect.width;
          const height = rect.height;
          const ratio = width / height;
          if (ratio > 0.85 && width > 500) {
            this.currentBreakpoint = 'MD';
          } else {
            this.currentBreakpoint = 'SM';
          }
        };
        updateBreakpoint();
        win.resize(420, 800);
        win.on('windowSizeChange', updateBreakpoint);
      });
    } catch (e) {
      console.error('监听窗口变化失败', e);
    }
  }

  private getCurrentCategories(): string[] {
    return this.isIncome ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;
  }

  private isTablet(): boolean {
    return this.currentBreakpoint === 'MD' || this.currentBreakpoint === 'LG';
  }

  // 解析日期字符串为 Date
  private parseDate(dateStr: string): Date {
    const parts = dateStr.split('-');
    return new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
  }

  // 切换到上一个类别
  private prevCategory() {
    const categories = this.getCurrentCategories();
    if (this.selectedCategoryIndex > 0) {
      this.selectedCategoryIndex--;
    } else {
      this.selectedCategoryIndex = categories.length - 1;
    }
  }

  // 切换到下一个类别
  private nextCategory() {
    const categories = this.getCurrentCategories();
    if (this.selectedCategoryIndex < categories.length - 1) {
      this.selectedCategoryIndex++;
    } else {
      this.selectedCategoryIndex = 0;
    }
  }

  clearAllRecords() {
    try {
      promptAction.showDialog({
        title: '确认清空',
        message: '确定要删除所有记账记录吗？此操作不可恢复！',
        buttons: [
          { text: '取消', color: '#999' },
          { text: '确定', color: '#E38A8B' }
        ]
      }).then((result) => {
        if (result.index === 1) {
          this.records = [];
          this.total = 0;
          this.saveData();
          promptAction.showToast({ message: '已清空所有记录', duration: 2000 });
        }
      });
    } catch (e) {
      console.error('Dialog报错', e);
    }
  }

  // 删除单条记录
  private deleteRecord(index: number) {
    const record = this.records[index];
    if (record.type === '收入') {
      this.total -= record.money;
    } else {
      this.total += record.money;
    }
    this.records.splice(index, 1);
    this.saveData();
    promptAction.showToast({ message: '已删除', duration: 1500 });
  }

  // 计算本月收入
  private getMonthIncome(): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '收入') {
        total += this.records[i].money;
      }
    }
    return total;
  }

  // 计算本月支出
  private getMonthExpense(): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '支出') {
        total += this.records[i].money;
      }
    }
    return total;
  }

  // 左滑删除按钮（用 @Builder 装饰）
  @Builder
  deleteButton(index: number) {
    Button('删除')
      .width(70)
      .height('100%')
      .fontSize(14)
      .fontColor('#FFFFFF')
      .backgroundColor('#E38A8B')
      .borderRadius(12)
      .onClick(() => {
        this.deleteRecord(index);
      });
  }

  build() {
    Column({ space: 10 }) {
      if (this.isTablet()) {
        Row({ space: 15 }) {
          Column() {
            Text('当前余额')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .opacity(0.8)
              .margin({ bottom: 5 });
            Text('¥ ' + this.total.toFixed(2))
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF');
          }
          .width('50%')
          .height(110)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F4A9AA')
          .shadow({ radius: 8, color: '#F4A9AA40', offsetX: 0, offsetY: 4 });

          Column({ space: 10 }) {
            Button('💰 收入')
              .backgroundColor(this.isIncome ? '#F4A9AA' : '#D9DDE0')
              .onClick(() => {
                this.isIncome = true;
                this.selectedCategoryIndex = 0;
              })
              .width('80%')
              .height(44)
              .borderRadius(22)
              .fontColor(this.isIncome ? '#FFFFFF' : '#3A3A3A')
              .fontWeight(FontWeight.Medium);
            Button('💸 支出')
              .backgroundColor(!this.isIncome ? '#F4A9AA' : '#D9DDE0')
              .onClick(() => {
                this.isIncome = false;
                this.selectedCategoryIndex = 0;
              })
              .width('80%')
              .height(44)
              .borderRadius(22)
              .fontColor(!this.isIncome ? '#FFFFFF' : '#3A3A3A')
              .fontWeight(FontWeight.Medium);
          }
          .width('40%')
          .alignItems(HorizontalAlign.Center);
        }
        .width('90%')
        .margin({ top: 15 });
      } else {
        Column() {
          Text('当前余额')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .opacity(0.8)
            .margin({ bottom: 5 });
          Text('¥ ' + this.total.toFixed(2))
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width('90%')
        .height(110)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F4A9AA')
        .shadow({ radius: 8, color: '#F4A9AA40', offsetX: 0, offsetY: 4 })
        .margin({ top: 15 });

        Row({ space: 12 }) {
          Button('收入')
            .backgroundColor(this.isIncome ? '#F4A9AA' : '#D9DDE0')
            .onClick(() => {
              this.isIncome = true;
              this.selectedCategoryIndex = 0;
            })
            .width('40%')
            .height(44)
            .borderRadius(22)
            .fontColor(this.isIncome ? '#FFFFFF' : '#3A3A3A')
            .fontWeight(FontWeight.Medium);
          Button('支出')
            .backgroundColor(!this.isIncome ? '#F4A9AA' : '#D9DDE0')
            .onClick(() => {
              this.isIncome = false;
              this.selectedCategoryIndex = 0;
            })
            .width('40%')
            .height(44)
            .borderRadius(22)
            .fontColor(!this.isIncome ? '#FFFFFF' : '#3A3A3A')
            .fontWeight(FontWeight.Medium);
        }
        .width('100%')
        .justifyContent(FlexAlign.Center);
      }

      if (this.isTablet()) {
        Row({ space: 12 }) {
          Row() {
            Text('选择类别')
              .fontSize(15)
              .fontColor('#3A3A3A')
              .width(70);
            Row() {
              Text('  <  ')
                .fontSize(18)
                .fontColor('#F4A9AA')
                .onClick(() => { this.prevCategory(); });
              Text(this.getCurrentCategories()[this.selectedCategoryIndex])
                .fontSize(15)
                .fontColor('#3A3A3A')
                .textAlign(TextAlign.Center)
                .backgroundColor('#FDE0E1')
                .borderRadius(8)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 });
              Text('  >  ')
                .fontSize(18)
                .fontColor('#F4A9AA')
                .onClick(() => { this.nextCategory(); });
            }
          }
          .width('45%')
          .justifyContent(FlexAlign.SpaceBetween);

          Row() {
            Text('选择日期')
              .fontSize(15)
              .fontColor('#3A3A3A')
              .width(70);
            DatePicker({
              start: new Date('2020-1-1'),
              end: new Date('2030-12-31'),
              selected: this.parseDate(this.selectedDate)
            })
              .onChange((value: DatePickerResult) => {
                const year = value.year;
                const month = (value.month! + 1).toString().padStart(2, '0');
                const day = value.day!.toString().padStart(2, '0');
                this.selectedDate = year + '-' + month + '-' + day;
              })
              .width(160)
              .height(48)
              .borderRadius(12)
              .backgroundColor('#FDE0E1')
              .textStyle({ color: '#3A3A3A' })
              .selectedTextStyle({ color: '#F4A9AA' });
          }
          .width('45%')
          .justifyContent(FlexAlign.SpaceBetween);
        }
        .width('80%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ top: 5, bottom: 5 });
      } else {
        Row() {
          Text('选择类别')
            .fontSize(15)
            .fontColor('#3A3A3A')
            .width(70);
          Row() {
            Text('  <  ')
              .fontSize(18)
              .fontColor('#F4A9AA')
              .onClick(() => { this.prevCategory(); });
            Text(this.getCurrentCategories()[this.selectedCategoryIndex])
              .fontSize(15)
              .fontColor('#3A3A3A')
              .textAlign(TextAlign.Center)
              .backgroundColor('#FDE0E1')
              .borderRadius(8)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 });
            Text('  >  ')
              .fontSize(18)
              .fontColor('#F4A9AA')
              .onClick(() => { this.nextCategory(); });
          }
        }
        .width('80%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ top: 5, bottom: 0 });

        Row() {
          Text('选择日期')
            .fontSize(15)
            .fontColor('#3A3A3A')
            .width(70);
          DatePicker({
            start: new Date('2020-1-1'),
            end: new Date('2030-12-31'),
            selected: this.parseDate(this.selectedDate)
          })
            .onChange((value: DatePickerResult) => {
              const year = value.year;
              const month = (value.month! + 1).toString().padStart(2, '0');
              const day = value.day!.toString().padStart(2, '0');
              this.selectedDate = year + '-' + month + '-' + day;
            })
            .width(160)
            .height(48)
            .borderRadius(12)
            .textStyle({ color: '#3A3A3A' })
            .selectedTextStyle({ color: '#F4A9AA' });
        }
        .width('80%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ top: 0, bottom: 0 });
      }

      if (this.isTablet()) {
        Row({ space: 12 }) {
          TextInput({ placeholder: '请输入金额' })
            .type(InputType.Number)
            .onChange((v: string) => this.money = v)
            .width('45%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#FDE0E1')
            .padding({ left: 16 })
            .fontColor('#555555')
            .placeholderColor('#999999');
          TextInput({ placeholder: '请输入备注（如：吃饭、工资）' })
            .onChange((v: string) => this.note = v)
            .width('45%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#FDE0E1')
            .padding({ left: 16 })
            .fontColor('#555555')
            .placeholderColor('#999999');
        }
        .width('80%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 5 });
      } else {
        TextInput({ placeholder: '请输入金额' })
          .type(InputType.Number)
          .onChange((v: string) => this.money = v)
          .width('80%')
          .margin({ top: 5 })
          .height(48)
          .borderRadius(12)
          .backgroundColor('#FDE0E1')
          .padding({ left: 16 })
          .fontColor('#555555')
          .placeholderColor('#999999');
        TextInput({ placeholder: '请输入备注（如：吃饭、工资）' })
          .onChange((v: string) => this.note = v)
          .width('80%')
          .margin({ top: 5 })
          .height(48)
          .borderRadius(12)
          .backgroundColor('#FDE0E1')
          .padding({ left: 16 })
          .fontColor('#555555')
          .placeholderColor('#999999');
      }

      Button('保存记录')
        .onClick(() => {
          const num: number = parseFloat(this.money);
          if (isNaN(num) || num <= 0) {
            promptAction.showToast({ message: '请输入有效金额', duration: 1500 });
            return;
          }
          if (this.isIncome) { this.total += num; }
          else { this.total -= num; }
          const selectedCategory = this.getCurrentCategories()[this.selectedCategoryIndex];
          this.records.unshift({
            type: this.isIncome ? '收入' : '支出',
            category: selectedCategory,
            money: num,
            note: this.note || '无备注',
            date: this.selectedDate
          });
          this.money = '';
          this.note = '';
          this.saveData();
        })
        .width('80%')
        .margin({ top: 3 })
        .height(48)
        .borderRadius(12)
        .backgroundColor('#F4A9AA')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .shadow({ radius: 4, color: '#F4A9AA60', offsetX: 0, offsetY: 2 });

      Button('清空所有记录')
        .onClick(() => this.clearAllRecords())
        .width('80%')
        .height(40)
        .borderRadius(12)
        .backgroundColor('#D9DDE0')
        .fontColor('#E38A8B')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 5 });

      Column() {
        Row() {
          Text('本月统计')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3A3A3A');
        }
        .width('90%')
        .margin({ top: 5, bottom: 5 });

        GridRow({ columns: 3, gutter: { x: 8, y: 0 } }) {
          GridCol() {
            Column() {
              Text('收入').fontSize(12).fontColor('#999999').margin({ bottom: 3 });
              Text('¥ ' + this.getMonthIncome().toFixed(2)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
            }
            .width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(12)
            .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
          }
          GridCol() {
            Column() {
              Text('支出').fontSize(12).fontColor('#999999').margin({ bottom: 3 });
              Text('¥ ' + this.getMonthExpense().toFixed(2)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
            }
            .width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(12)
            .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
          }
          GridCol() {
            Column() {
              Text('结余').fontSize(12).fontColor('#999999').margin({ bottom: 3 });
              Text('¥ ' + (this.getMonthIncome() - this.getMonthExpense()).toFixed(2)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
            }
            .width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(12)
            .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
          }
        }
        .width('90%');
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);

      Text('历史记录')
        .fontSize(18)
        .margin({ top: 5, bottom: 5 })
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .width('90%');

      if (this.isTablet()) {
        Scroll() {
          GridRow({ columns: 2, gutter: { x: 8, y: 8 } }) {
            ForEach(this.records, (item: BillRecord, index: number) => {
              GridCol() {
                Row() {
                  Column() {
                    Text(item.category).fontSize(13).fontColor('#BCC2C3');
                    Text(item.type + '：¥' + item.money.toFixed(2))
                      .fontSize(16).fontColor(item.type === '收入' ? '#F4A9AA' : '#E38A8B').fontWeight(FontWeight.Bold).margin({ top: 2 });
                  }
                  .alignItems(HorizontalAlign.Start);
                  Blank();
                  Column() {
                    Text(item.date || '').fontSize(11).fontColor('#999999');
                    Text(item.note || '').fontSize(13).fontColor('#3A3A3A').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .alignItems(HorizontalAlign.End);
                }
                .width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
                .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
              }
            }, (item: BillRecord, index: number) => index.toString() + item.money + item.note)
          }
          .width('90%');
        }
        .layoutWeight(1)
        .width('100%');
      } else {
        Scroll() {
          List({ space: 8 }) {
            ForEach(this.records, (item: BillRecord, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.category).fontSize(13).fontColor('#BCC2C3');
                    Text(item.type + '：¥' + item.money.toFixed(2))
                      .fontSize(16).fontColor(item.type === '收入' ? '#F4A9AA' : '#E38A8B').fontWeight(FontWeight.Bold).margin({ top: 2 });
                  }
                  .alignItems(HorizontalAlign.Start);
                  Blank();
                  Column() {
                    Text(item.date || '').fontSize(11).fontColor('#999999');
                    Text(item.note || '').fontSize(13).fontColor('#3A3A3A').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .alignItems(HorizontalAlign.End);
                }
                .width('90%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
                .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
              }
              .swipeAction({ end: this.deleteButton(index) })
            }, (item: BillRecord, index: number) => index.toString() + item.money + item.note)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%');
      }
    }
    .width('100%')
    .height('100%')
    .padding(15)
    .backgroundColor('#FFF5F5');
  }
}