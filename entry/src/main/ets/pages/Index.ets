import promptAction from '@ohos.promptAction';

// 1. 原有接口（新增 category 字段）
interface BillRecord {
  type: string;
  category: string;
  money: number;
  note: string;
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

  private getCurrentCategories(): string[] {
    return this.isIncome ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;
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
    promptAction.showToast({ message: '已删除', duration: 1500 });
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
      // 余额卡片
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

      // 收入/支出切换
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

      // 类别选择器
      Row() {
        Text('选择类别')
          .fontSize(15)
          .fontColor('#3A3A3A')
          .width(70);

        Row() {
          Text('  <  ')
            .fontSize(18)
            .fontColor('#F4A9AA')
            .onClick(() => {
              this.prevCategory();
            });

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
            .onClick(() => {
              this.nextCategory();
            });
        }
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ top: 5, bottom: 5 });

      // 金额输入框
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

      // 备注输入框
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

      // 保存按钮
      Button('保存记录')
        .onClick(() => {
          const num: number = parseFloat(this.money);
          if (isNaN(num) || num <= 0) {
            promptAction.showToast({ message: '请输入有效金额', duration: 1500 });
            return;
          }
          if (this.isIncome) {
            this.total += num;
          } else {
            this.total -= num;
          }
          const selectedCategory = this.getCurrentCategories()[this.selectedCategoryIndex];
          this.records.unshift({
            type: this.isIncome ? '收入' : '支出',
            category: selectedCategory,
            money: num,
            note: this.note || '无备注'
          });
          this.money = '';
          this.note = '';
        })
        .width('80%')
        .margin({ top: 10 })
        .height(48)
        .borderRadius(12)
        .backgroundColor('#F4A9AA')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .shadow({ radius: 4, color: '#F4A9AA60', offsetX: 0, offsetY: 2 });

      // 清空按钮
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

      // 历史记录标题
      Text('历史记录')
        .fontSize(18)
        .margin({ top: 5, bottom: 5 })
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .width('90%');

      // 记录列表（支持左滑删除）
      Scroll() {
        List({ space: 8 }) {
          ForEach(this.records, (item: BillRecord, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.category)
                    .fontSize(13)
                    .fontColor('#BCC2C3');
                  Text(item.type + '：¥' + item.money.toFixed(2))
                    .fontSize(16)
                    .fontColor(item.type === '收入' ? '#F4A9AA' : '#E38A8B')
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start);
                Blank();
                Text(item.note || '')
                  .fontSize(13)
                  .fontColor('#3A3A3A')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .width('90%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
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
    .width('100%')
    .height('100%')
    .padding(15)
    .backgroundColor('#FFF5F5');
  }
}