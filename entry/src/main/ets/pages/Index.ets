import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import window from '@ohos.window';

interface ChartItem {
  category: string;
  amount: number;
  color: string;
}

interface CalendarCell {
  text: string;
  color: string;
  isEmpty: boolean;
}

interface CalendarRow {
  days: CalendarCell[];
}

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
  @State currentTab: number = 0;

  private dataPreferences: preferences.Preferences | null = null;

  async initPreferences() {
    try {
      this.dataPreferences = await preferences.getPreferences(getContext(), 'bill_data');
      const totalStr = await this.dataPreferences.get('total', '0') as string;
      this.total = parseFloat(totalStr);
      const recordsStr = await this.dataPreferences.get('records', '[]') as string;
      this.records = JSON.parse(recordsStr);
      const shopStr = await this.dataPreferences!.get('shopping', '[]') as string;
      this.shoppingList = JSON.parse(shopStr);
      const boughtStr = await this.dataPreferences!.get('bought', '[]') as string;
      this.boughtList = JSON.parse(boughtStr);
    } catch (e) {
      console.error('加载数据失败', e);
    }
  }

  async saveData() {
    try {
      if (this.dataPreferences) {
        await this.dataPreferences.put('total', this.total.toString());
        await this.dataPreferences.put('records', JSON.stringify(this.records));
        await this.dataPreferences!.put('shopping', JSON.stringify(this.shoppingList));
        await this.dataPreferences!.put('bought', JSON.stringify(this.boughtList));
        await this.dataPreferences.flush();
        AppStorage.setOrCreate('total', this.total);
        AppStorage.setOrCreate('records', JSON.stringify(this.records));
      }
    } catch (e) {
      console.error('保存数据失败', e);
    }
  }

  aboutToAppear() {
    this.initPreferences();
    try {
      const savedTotal = AppStorage.get<number>('total');
      const savedRecords = AppStorage.get<string>('records');
      if (savedTotal) { this.total = savedTotal; }
      if (savedRecords) { this.records = JSON.parse(savedRecords); }
    } catch (e) {}
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

  private parseDate(dateStr: string): Date {
    const parts = dateStr.split('-');
    return new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
  }

  private prevCategory() {
    const categories = this.getCurrentCategories();
    if (this.selectedCategoryIndex > 0) {
      this.selectedCategoryIndex--;
    } else {
      this.selectedCategoryIndex = categories.length - 1;
    }
  }

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

  private getMonthIncome(): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '收入') {
        total += this.records[i].money;
      }
    }
    return total;
  }

  private getMonthExpense(): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '支出') {
        total += this.records[i].money;
      }
    }
    return total;
  }

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

  // ==================== 首页 ====================
  @Builder
  HomePage() {
    Column({ space: 10 }) {
      if (this.isTablet()) {
        Row() {
          Blank('5%')
          Column() {
            Text('当前余额').fontSize(14).fontColor('#FFFFFF').opacity(0.8).margin({ bottom: 5 });
            Text('¥ ' + this.total.toFixed(2)).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
          }
          .width('50%').height(110).borderRadius(20).justifyContent(FlexAlign.Center)
          .backgroundColor('#F4A9AA').shadow({ radius: 8, color: '#F4A9AA40', offsetX: 0, offsetY: 4 });

          Blank('10%')

          Column({ space: 10 }) {
            Button('收入').backgroundColor(this.isIncome ? '#F4A9AA' : '#D9DDE0')
              .onClick(() => { this.isIncome = true; this.selectedCategoryIndex = 0; })
              .width('80%').height(44).borderRadius(22)
              .fontColor(this.isIncome ? '#FFFFFF' : '#3A3A3A').fontWeight(FontWeight.Medium);
            Button('支出').backgroundColor(!this.isIncome ? '#F4A9AA' : '#D9DDE0')
              .onClick(() => { this.isIncome = false; this.selectedCategoryIndex = 0; })
              .width('80%').height(44).borderRadius(22)
              .fontColor(!this.isIncome ? '#FFFFFF' : '#3A3A3A').fontWeight(FontWeight.Medium);
          }
          .width('40%').alignItems(HorizontalAlign.Center);

          Blank('5%')
        }
        .width('100%').margin({ top: 15 });
      } else {
        Column() {
          Text('当前余额').fontSize(14).fontColor('#FFFFFF').opacity(0.8).margin({ bottom: 5 });
          Text('¥ ' + this.total.toFixed(2)).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
        }
        .width('90%').height(110).borderRadius(20).justifyContent(FlexAlign.Center)
        .backgroundColor('#F4A9AA').shadow({ radius: 8, color: '#F4A9AA40', offsetX: 0, offsetY: 4 }).margin({ top: 15 });

        Row({ space: 12 }) {
          Button('收入').backgroundColor(this.isIncome ? '#F4A9AA' : '#D9DDE0')
            .onClick(() => { this.isIncome = true; this.selectedCategoryIndex = 0; })
            .width('40%').height(44).borderRadius(22)
            .fontColor(this.isIncome ? '#FFFFFF' : '#3A3A3A').fontWeight(FontWeight.Medium);
          Button('支出').backgroundColor(!this.isIncome ? '#F4A9AA' : '#D9DDE0')
            .onClick(() => { this.isIncome = false; this.selectedCategoryIndex = 0; })
            .width('40%').height(44).borderRadius(22)
            .fontColor(!this.isIncome ? '#FFFFFF' : '#3A3A3A').fontWeight(FontWeight.Medium);
        }
        .width('100%').justifyContent(FlexAlign.Center);
      }

      if (this.isTablet()) {
        Row({ space: 12 }) {
          Row() {
            Text('选择类别').fontSize(15).fontColor('#3A3A3A').width(70);
            Row() {
              Text('  <  ').fontSize(18).fontColor('#F4A9AA').onClick(() => { this.prevCategory(); });
              Text(this.getCurrentCategories()[this.selectedCategoryIndex]).fontSize(15).fontColor('#3A3A3A')
                .textAlign(TextAlign.Center).backgroundColor('#FDE0E1').borderRadius(8)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 });
              Text('  >  ').fontSize(18).fontColor('#F4A9AA').onClick(() => { this.nextCategory(); });
            }
          }.width('45%').justifyContent(FlexAlign.SpaceBetween);

          Row() {
            Text('选择日期').fontSize(15).fontColor('#3A3A3A').width(70);
            DatePicker({ start: new Date('2020-1-1'), end: new Date('2030-12-31'), selected: this.parseDate(this.selectedDate) })
              .onChange((value: DatePickerResult) => {
                const year = value.year; const month = (value.month! + 1).toString().padStart(2, '0');
                const day = value.day!.toString().padStart(2, '0'); this.selectedDate = year + '-' + month + '-' + day;
              })
              .width(160).height(48).borderRadius(12).backgroundColor('#FDE0E1')
              .textStyle({ color: '#3A3A3A' }).selectedTextStyle({ color: '#F4A9AA' });
          }.width('45%').justifyContent(FlexAlign.SpaceBetween);
        }.width('80%').justifyContent(FlexAlign.SpaceBetween).padding({ top: 5, bottom: 5 });
      } else {
        Row() {
          Text('选择类别').fontSize(15).fontColor('#3A3A3A').width(70);
          Row() {
            Text('  <  ').fontSize(18).fontColor('#F4A9AA').onClick(() => { this.prevCategory(); });
            Text(this.getCurrentCategories()[this.selectedCategoryIndex]).fontSize(15).fontColor('#3A3A3A')
              .textAlign(TextAlign.Center).backgroundColor('#FDE0E1').borderRadius(8)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 });
            Text('  >  ').fontSize(18).fontColor('#F4A9AA').onClick(() => { this.nextCategory(); });
          }
        }.width('80%').justifyContent(FlexAlign.SpaceBetween).padding({ top: 5, bottom: 0 });

        Row() {
          Text('选择日期').fontSize(15).fontColor('#3A3A3A').width(70);
          DatePicker({ start: new Date('2020-1-1'), end: new Date('2030-12-31'), selected: this.parseDate(this.selectedDate) })
            .onChange((value: DatePickerResult) => {
              const year = value.year; const month = (value.month! + 1).toString().padStart(2, '0');
              const day = value.day!.toString().padStart(2, '0'); this.selectedDate = year + '-' + month + '-' + day;
            })
            .width(160).height(48).borderRadius(12)
            .textStyle({ color: '#3A3A3A' }).selectedTextStyle({ color: '#F4A9AA' });
        }.width('80%').justifyContent(FlexAlign.SpaceBetween).padding({ top: 0, bottom: 0 });
      }

      if (this.isTablet()) {
        Row({ space: 12 }) {
          TextInput({ placeholder: '请输入金额' }).type(InputType.Number).onChange((v: string) => this.money = v)
            .width('45%').height(48).borderRadius(12).backgroundColor('#FDE0E1').padding({ left: 16 })
            .fontColor('#555555').placeholderColor('#999999');
          TextInput({ placeholder: '请输入备注（如：吃饭、工资）' }).onChange((v: string) => this.note = v)
            .width('45%').height(48).borderRadius(12).backgroundColor('#FDE0E1').padding({ left: 16 })
            .fontColor('#555555').placeholderColor('#999999');
        }.width('80%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 5 });
      } else {
        TextInput({ placeholder: '请输入金额' }).type(InputType.Number).onChange((v: string) => this.money = v)
          .width('80%').margin({ top: 5 }).height(48).borderRadius(12).backgroundColor('#FDE0E1').padding({ left: 16 })
          .fontColor('#555555').placeholderColor('#999999');
        TextInput({ placeholder: '请输入备注（如：吃饭、工资）' }).onChange((v: string) => this.note = v)
          .width('80%').margin({ top: 5 }).height(48).borderRadius(12).backgroundColor('#FDE0E1').padding({ left: 16 })
          .fontColor('#555555').placeholderColor('#999999');
      }

      Button('保存记录')
        .onClick(() => {
          const num: number = parseFloat(this.money);
          if (isNaN(num) || num <= 0) { promptAction.showToast({ message: '请输入有效金额', duration: 1500 }); return; }
          if (this.isIncome) { this.total += num; } else { this.total -= num; }
          const selectedCategory = this.getCurrentCategories()[this.selectedCategoryIndex];
          this.records.unshift({ type: this.isIncome ? '收入' : '支出', category: selectedCategory, money: num, note: this.note || '无备注', date: this.selectedDate });
          this.money = ''; this.note = ''; this.saveData();
        })
        .width('80%').margin({ top: 3 }).height(48).borderRadius(12)
        .backgroundColor('#F4A9AA').fontColor('#FFFFFF').fontSize(16).fontWeight(FontWeight.Medium)
        .shadow({ radius: 4, color: '#F4A9AA60', offsetX: 0, offsetY: 2 });

      Button('清空所有记录').onClick(() => this.clearAllRecords())
        .width('80%').height(40).borderRadius(12).backgroundColor('#D9DDE0')
        .fontColor('#E38A8B').fontSize(14).fontWeight(FontWeight.Medium).margin({ top: 5 });

      Text('历史记录').fontSize(18).margin({ top: 5, bottom: 5 }).fontWeight(FontWeight.Bold).fontColor('#3A3A3A').width('90%');

      if (this.isTablet()) {
        Scroll() {
          GridRow({ columns: 2, gutter: { x: 8, y: 8 } }) {
            ForEach(this.records, (item: BillRecord, index: number) => {
              GridCol() {
                Row() {
                  Column() {
                    Text(item.category).fontSize(13).fontColor('#BCC2C3');
                    Text(item.type + '：¥' + item.money.toFixed(2)).fontSize(16)
                      .fontColor(item.type === '收入' ? '#F4A9AA' : '#E38A8B').fontWeight(FontWeight.Bold).margin({ top: 2 });
                  }.alignItems(HorizontalAlign.Start);
                  Blank();
                  Column() {
                    Text(item.date || '').fontSize(11).fontColor('#999999');
                    Text(item.note || '').fontSize(13).fontColor('#3A3A3A').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }.alignItems(HorizontalAlign.End);
                }
                .width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
                .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
              }
            }, (item: BillRecord, index: number) => index.toString() + item.money + item.note)
          }.width('90%');
        }.layoutWeight(1).width('100%');
      } else {
        Scroll() {
          List({ space: 8 }) {
            ForEach(this.records, (item: BillRecord, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.category).fontSize(13).fontColor('#BCC2C3');
                    Text(item.type + '：¥' + item.money.toFixed(2)).fontSize(16)
                      .fontColor(item.type === '收入' ? '#F4A9AA' : '#E38A8B').fontWeight(FontWeight.Bold).margin({ top: 2 });
                  }.alignItems(HorizontalAlign.Start);
                  Blank();
                  Column() {
                    Text(item.date || '').fontSize(11).fontColor('#999999');
                    Text(item.note || '').fontSize(13).fontColor('#3A3A3A').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }.alignItems(HorizontalAlign.End);
                }
                .width('90%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
                .shadow({ radius: 4, color: '#D9DDE0', offsetX: 0, offsetY: 2 });
              }
              .swipeAction({ end: this.deleteButton(index) })
            }, (item: BillRecord, index: number) => index.toString() + item.money + item.note)
          }.width('100%').alignListItem(ListItemAlign.Center)
        }.layoutWeight(1).width('100%');
      }
    }
    .width('100%').height('100%');
  }

  // ==================== 报表 ====================
  @State reportMonth: string = (new Date().getMonth() + 1) + '月';
  @State reportYear: number = new Date().getFullYear();
  @State reportMonthIndex: number = new Date().getMonth();
  @State showIncome: boolean = false;
  @State showCalendar: boolean = false;
  @State calendarMode: string = '支出';

  private prevMonth() {
    if (this.reportMonthIndex === 0) { this.reportMonthIndex = 11; this.reportYear--; }
    else { this.reportMonthIndex--; }
    this.reportMonth = (this.reportMonthIndex + 1) + '月';
  }

  private nextMonth() {
    if (this.reportMonthIndex === 11) { this.reportMonthIndex = 0; this.reportYear++; }
    else { this.reportMonthIndex++; }
    this.reportMonth = (this.reportMonthIndex + 1) + '月';
  }

  private getMonthIncomeByMonth(year: number, month: number): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '收入') {
        const parts = this.records[i].date.split('-');
        if (parseInt(parts[0]) === year && parseInt(parts[1]) - 1 === month) { total += this.records[i].money; }
      }
    }
    return total;
  }

  private getMonthExpenseByMonth(year: number, month: number): number {
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].type === '支出') {
        const parts = this.records[i].date.split('-');
        if (parseInt(parts[0]) === year && parseInt(parts[1]) - 1 === month) { total += this.records[i].money; }
      }
    }
    return total;
  }

  private getExpenseChartData(): ChartItem[] {
    const colors = ['#F4A9AA', '#E38A8B', '#FAD1D2', '#F7BFC0', '#ED9C9D', '#E58384', '#F2B5B6', '#FACBCB', '#F5A0A1', '#E47A7B', '#F6B2B3'];
    const result: ChartItem[] = [];
    for (let i = 0; i < EXPENSE_CATEGORIES.length; i++) {
      let amount = 0;
      for (let j = 0; j < this.records.length; j++) {
        if (this.records[j].type === '支出' && this.records[j].category === EXPENSE_CATEGORIES[i]) {
          const parts = this.records[j].date.split('-');
          if (parseInt(parts[0]) === this.reportYear && parseInt(parts[1]) - 1 === this.reportMonthIndex) { amount += this.records[j].money; }
        }
      }
      if (amount > 0) { result.push({ category: EXPENSE_CATEGORIES[i], amount: amount, color: colors[i] }); }
    }
    result.sort((a, b) => b.amount - a.amount);
    return result;
  }

  private getIncomeChartData(): ChartItem[] {
    const colors = ['#F4A9AA', '#E38A8B', '#FAD1D2', '#F7BFC0', '#ED9C9D'];
    const result: ChartItem[] = [];
    for (let i = 0; i < INCOME_CATEGORIES.length; i++) {
      let amount = 0;
      for (let j = 0; j < this.records.length; j++) {
        if (this.records[j].type === '收入' && this.records[j].category === INCOME_CATEGORIES[i]) {
          const parts = this.records[j].date.split('-');
          if (parseInt(parts[0]) === this.reportYear && parseInt(parts[1]) - 1 === this.reportMonthIndex) { amount += this.records[j].money; }
        }
      }
      if (amount > 0) { result.push({ category: INCOME_CATEGORIES[i], amount: amount, color: colors[i] }); }
    }
    result.sort((a, b) => b.amount - a.amount);
    return result;
  }

  private getPercentText(amount: number, total: number): string {
    if (total === 0) return '0%';
    return (amount / total * 100).toFixed(1) + '%';
  }

  private getDayAmount(year: number, month: number, day: number): number {
    const dateStr = year + '-' + (month + 1).toString().padStart(2, '0') + '-' + day.toString().padStart(2, '0');
    let total = 0;
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].date === dateStr && this.records[i].type === this.calendarMode) { total += this.records[i].money; }
    }
    return total;
  }

  private getCalendarColor(amount: number): string {
    if (this.calendarMode === '支出') {
      if (amount === 0) return '#FFFFFF';
      if (amount < 200) return '#FDE0E1';
      if (amount < 1000) return '#F4A9AA';
      return '#E38A8B';
    } else {
      if (amount === 0) return '#FFFFFF';
      if (amount <= 100) return '#F5F5F5';
      return '#D9DDE0';
    }
  }

  private getDaysInMonth(year: number, month: number): number {
    return new Date(year, month + 1, 0).getDate();
  }

  @Builder
  CalendarDialog() {
    Column({ space: 8 }) {
      Row() {
        Text('日历').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        Blank();
        Button('✕').fontSize(14).width(28).height(28)
          .fontColor('#999999').backgroundColor('#F5F5F5').borderRadius(14)
          .onClick(() => { this.showCalendar = false; });
      }.width('100%');

      Row({ space: 10 }) {
        Button('支出').fontSize(13).width('35%').height(30).borderRadius(15)
          .fontColor(this.calendarMode === '支出' ? '#FFFFFF' : '#999999')
          .backgroundColor(this.calendarMode === '支出' ? '#E38A8B' : '#F5F5F5')
          .onClick(() => { this.calendarMode = '支出'; });
        Button('收入').fontSize(13).width('35%').height(30).borderRadius(15)
          .fontColor(this.calendarMode === '收入' ? '#FFFFFF' : '#999999')
          .backgroundColor(this.calendarMode === '收入' ? '#F4A9AA' : '#F5F5F5')
          .onClick(() => { this.calendarMode = '收入'; });
      }.width('100%').justifyContent(FlexAlign.Center);


      // 日均
      // 日均
      Row() {
        Text('日均' + this.calendarMode).fontSize(12).fontColor('#999999');
        Text('¥ ' + (this.calendarMode === '支出' ? this.getAvgExpense() : this.getAvgIncome()).toFixed(0))
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.calendarMode === '支出' ? '#E38A8B' : '#F4A9AA').margin({ left: 6 });
      }
      .width('100%').justifyContent(FlexAlign.Center).margin({ top: 5, bottom: 8 });

      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
          Text(day).fontSize(11).fontColor('#999999').width('13%').textAlign(TextAlign.Center);
        })
      }.width('100%');

      this.CalendarGrid();
    }
    .width('90%').padding(15).backgroundColor('#FFFFFF').borderRadius(16);
  }

  @Builder
  CalendarGrid() {
    Column({ space: 4 }) {
      ForEach(this.getCalendarRows(), (row: CalendarRow) => {
        Row() {
          ForEach(row.days, (cell: CalendarCell) => {
            if (cell.isEmpty) {
              Text('').width('13%').height(36);
            } else {
              Text(cell.text).fontSize(12).fontColor('#3A3A3A').width('13%').height(36)
                .backgroundColor(cell.color).borderRadius(6).textAlign(TextAlign.Center);
            }
          })
        }.width('100%');
      })
    }.width('100%').margin({ top: 5 });
  }

  private getCalendarRows(): CalendarRow[] {
    const firstDay = new Date(this.reportYear, this.reportMonthIndex, 1).getDay();
    const daysInMonth = this.getDaysInMonth(this.reportYear, this.reportMonthIndex);
    const rows: CalendarRow[] = [];
    let dayCount = 1;

    for (let row = 0; row < 6; row++) {
      const cells: CalendarCell[] = [];
      for (let col = 0; col < 7; col++) {
        if ((row === 0 && col < firstDay) || dayCount > daysInMonth) {
          cells.push({ text: '', color: '#FFFFFF', isEmpty: true });
        } else {
          const amount = this.getDayAmount(this.reportYear, this.reportMonthIndex, dayCount);
          const color = this.getCalendarColor(amount);
          cells.push({ text: dayCount.toString(), color: color, isEmpty: false });
          dayCount++;
        }
      }
      rows.push({ days: cells });
      if (dayCount > daysInMonth) break;
    }
    return rows;
  }

  @Builder
  ReportPage() {
    Column({ space: 2 }) {
      Row() {
        Text('  <  ').fontSize(20).fontColor('#F4A9AA').onClick(() => { this.prevMonth(); });
        Text(this.reportYear + '年' + this.reportMonth).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        Text('  >  ').fontSize(20).fontColor('#F4A9AA').onClick(() => { this.nextMonth(); });
        Button('📅').fontSize(14).width(32).height(32).backgroundColor('#FDE0E1').borderRadius(16)
          .onClick(() => { this.showCalendar = true; });
      }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 10, bottom: 5 });

      Row({ space: 6 }) {
        Column() {
          Text('收入').fontSize(11).fontColor('#999999').margin({ bottom: 2 });
          Text(this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex).toFixed(0))
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
        }.width('30%').padding(10).backgroundColor(this.showIncome ? '#FFF0F0' : '#FFFFFF').borderRadius(10)
        .onClick(() => { this.showIncome = true; });

        Column() {
          Text('支出').fontSize(11).fontColor('#999999').margin({ bottom: 2 });
          Text(this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex).toFixed(0))
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#E38A8B');
        }.width('30%').padding(10).backgroundColor(this.showIncome ? '#FFFFFF' : '#FFF0F0').borderRadius(10)
        .onClick(() => { this.showIncome = false; });

        Column() {
          Text('结余').fontSize(11).fontColor('#999999').margin({ bottom: 2 });
          Text((this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex) - this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex)).toFixed(0))
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        }.width('30%').padding(10).backgroundColor('#FFFFFF').borderRadius(10);
      }
      .width('95%').justifyContent(FlexAlign.Center).margin({ top: 5, bottom: 2 });

      Scroll() {
        Column({ space: 4 }) {
          ForEach(this.showIncome ? this.getIncomeChartData() : this.getExpenseChartData(), (item: ChartItem) => {
            Column() {
              Row() {
                Text(item.category).fontSize(12).fontColor('#3A3A3A');
                Blank();
                Text('¥ ' + item.amount.toFixed(0)).fontSize(12).fontWeight(FontWeight.Bold)
                  .fontColor(this.showIncome ? '#F4A9AA' : '#E38A8B');
              }.width('100%');
              Row() {
                Progress({ value: item.amount, total: this.showIncome ? (this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex) > 0 ? this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex) : 1) : (this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex) > 0 ? this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex) : 1), type: ProgressType.Linear })
                  .width('100%').height(5).color(item.color).backgroundColor('#F5F5F5');
              }.width('100%').margin({ top: 3 });
              Text(this.getPercentText(item.amount, this.showIncome ? this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex) : this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex)))
                .fontSize(10).fontColor('#BBBBBB').margin({ top: 2 });
            }
            .width('100%').padding(8).backgroundColor('#FFFFFF').borderRadius(8);
          })
        }.width('90%').alignItems(HorizontalAlign.Center);
      }
      .flexShrink(1).width('100%');
    }
    .width('100%').alignItems(HorizontalAlign.Center);
  }

  private getDaysInCurrentMonth(): number {
    return new Date(this.reportYear, this.reportMonthIndex + 1, 0).getDate();
  }

  private getAvgExpense(): number {
    const total = this.getMonthExpenseByMonth(this.reportYear, this.reportMonthIndex);
    const days = this.getDaysInCurrentMonth();
    return days > 0 ? total / days : 0;
  }

  private getAvgIncome(): number {
    const total = this.getMonthIncomeByMonth(this.reportYear, this.reportMonthIndex);
    const days = this.getDaysInCurrentMonth();
    return days > 0 ? total / days : 0;
  }


  // ==================== 我的 ====================
  @State userName: string = '北北';
  @State userAvatar: string = '';
  @State showShopping: boolean = false;
  @State showExchange: boolean = false;
  @State showSalary: boolean = false;
  @State shoppingList: string[] = [];
  @State shoppingInput: string = '';
  @State boughtList: boolean[] = [];
  @State exchangeRate: number = 7.25;
  @State exchangeCurrency: string = '美元';
  @State exchangeLabel: string = 'USD';
  @State cnyAmount: string = '';
  @State usdAmount: string = '';
  @State exchangeMode: boolean = true; // true=人民币转外币
  @State salaryInput: string = '';
  @State salaryResult: string = '';
  @State taxAmount: string = '';
  @State socialAmount: string = '';

  @Builder
  MinePage() {
    Column({ space: 15 }) {
      // 头像和昵称
      Column() {
        Text('')
          .fontSize(48)
          .width(80).height(80)
          .backgroundColor('#FDE0E1').borderRadius(40)
          .textAlign(TextAlign.Center);

        Row() {
          Text(this.userName).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
          Text(' ').fontSize(14).fontColor('#999999').onClick(() => { this.userName = '北北'; });
        }.margin({ top: 10 });
      }
      .width('80%').padding(20).backgroundColor('#FFFFFF').borderRadius(16)
      .margin({ top: 20 });

      // 功能列表
      if (this.isTablet()) {
        Row({ space: 8 }) {
          Column() {
            Text('🛒').fontSize(28);
            Text('购物清单').fontSize(11).fontColor('#3A3A3A').margin({ top: 5 });
          }
          .width('30%').padding(12).backgroundColor('#FFFFFF').borderRadius(10)
          .onClick(() => { this.showShopping = true; });

          Column() {
            Text('💱').fontSize(28);
            Text('汇率换算').fontSize(11).fontColor('#3A3A3A').margin({ top: 5 });
          }
          .width('30%').padding(12).backgroundColor('#FFFFFF').borderRadius(10)
          .onClick(() => { this.showExchange = true; });

          Column() {
            Text('💼').fontSize(28);
            Text('薪水计算').fontSize(11).fontColor('#3A3A3A').margin({ top: 5 });
          }
          .width('30%').padding(12).backgroundColor('#FFFFFF').borderRadius(10)
          .onClick(() => { this.showSalary = true; });
        }
        .width('80%').justifyContent(FlexAlign.Center).margin({ top: 10 });
      } else {
        Column({ space: 10 }) {
          Row() {
            Text('🛒').fontSize(22);
            Text('购物清单').fontSize(15).fontColor('#3A3A3A').margin({ left: 10 });
            Blank();
            Text('>').fontSize(16).fontColor('#CCCCCC');
          }
          .width('80%').padding(15).backgroundColor('#FFFFFF').borderRadius(12)
          .onClick(() => { this.showShopping = true; });

          Row() {
            Text('💱').fontSize(22);
            Text('汇率换算').fontSize(15).fontColor('#3A3A3A').margin({ left: 10 });
            Blank();
            Text('>').fontSize(16).fontColor('#CCCCCC');
          }
          .width('80%').padding(15).backgroundColor('#FFFFFF').borderRadius(12)
          .onClick(() => { this.showExchange = true; });

          Row() {
            Text('💼').fontSize(22);
            Text('薪水计算').fontSize(15).fontColor('#3A3A3A').margin({ left: 10 });
            Blank();
            Text('>').fontSize(16).fontColor('#CCCCCC');
          }
          .width('80%').padding(15).backgroundColor('#FFFFFF').borderRadius(12)
          .onClick(() => { this.showSalary = true; });
        }
        .width('100%').margin({ top: 10 });
      }
    }
    .width('100%').height('100%');
  }

  @Builder
  ShoppingDialog() {
    Column({ space: 10 }) {
      // 标题
      Row() {
        Text('购物清单').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        Blank();
        Button('✕').fontSize(14).width(28).height(28)
          .fontColor('#999999').backgroundColor('#F5F5F5').borderRadius(14)
          .onClick(() => { this.showShopping = false; });
      }.width('100%');

      // 输入框
      Row({ space: 8 }) {
        TextInput({ placeholder: '添加物品...' })
          .onChange((v: string) => { this.shoppingInput = v; })
          .width('70%').height(40).borderRadius(10)
          .backgroundColor('#F5F5F5').padding({ left: 12 });
        Button('添加')
          .width('25%').height(40).borderRadius(10)
          .backgroundColor('#F4A9AA').fontColor('#FFFFFF').fontSize(14)
          .onClick(() => {
            if (this.shoppingInput.trim() !== '') {
              this.shoppingList.push(this.shoppingInput.trim());
              this.boughtList.push(false);
              this.shoppingInput = '';
            }
          });
      }.width('100%');

      // 列表
      Scroll() {
        Column({ space: 6 }) {
          ForEach(this.shoppingList, (item: string, index: number) => {
            Row() {
              Text(this.boughtList[index] ? '√' : 'O')
                .fontSize(18)
                .onClick(() => {
                  this.boughtList[index] = !this.boughtList[index];
                  this.saveData();
                });
              Text(item)
                .fontSize(15).fontColor(this.boughtList[index] ? '#CCCCCC' : '#3A3A3A')
                .decoration({ type: this.boughtList[index] ? TextDecorationType.LineThrough : TextDecorationType.None })
                .margin({ left: 8 }).layoutWeight(1);
              Button('×').fontSize(14).width(32).height(32)
                .backgroundColor('#FFF0F0').borderRadius(16)
                .onClick(() => { this.shoppingList.splice(index, 1); this.boughtList.splice(index, 1); });
            }
            .width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(8);
          })
        }.width('100%');
      }
      .layoutWeight(1).width('100%');

      // 清空按钮
      Button('清空清单')
        .width('100%').height(36).borderRadius(10)
        .backgroundColor('#F5F5F5').fontColor('#999999').fontSize(13)
        .onClick(() => {
          this.shoppingList = [];
          this.boughtList = [];
          this.saveData();
        });
    }
    .width('85%').height('60%').padding(20).backgroundColor('#FFFFFF').borderRadius(16);
  }

  @Builder
  ExchangeDialog() {
    Column({ space: 12 }) {
      Row() {
        Text('💱 汇率换算').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        Blank();
        Button('✕').fontSize(14).width(28).height(28)
          .fontColor('#999999').backgroundColor('#F5F5F5').borderRadius(14)
          .onClick(() => { this.showExchange = false; });
      }.width('100%');

      Row({ space: 6 }) {
        ForEach(['美元', '欧元', '日元', '港币', '韩元', '英镑'], (cur: string) => {
          Button(cur)
            .fontSize(11).height(28).borderRadius(14).padding({ left: 8, right: 8 })
            .fontColor(this.exchangeCurrency === cur ? '#FFFFFF' : '#999999')
            .backgroundColor(this.exchangeCurrency === cur ? '#F4A9AA' : '#F5F5F5')
            .onClick(() => {
              this.exchangeCurrency = cur;
              if (cur === '美元') { this.exchangeRate = 7.25; this.exchangeLabel = 'USD'; }
              if (cur === '欧元') { this.exchangeRate = 7.85; this.exchangeLabel = 'EUR'; }
              if (cur === '日元') { this.exchangeRate = 0.048; this.exchangeLabel = 'JPY'; }
              if (cur === '港币') { this.exchangeRate = 0.93; this.exchangeLabel = 'HKD'; }
              if (cur === '韩元') { this.exchangeRate = 0.0054; this.exchangeLabel = 'KRW'; }
              if (cur === '英镑') { this.exchangeRate = 9.20; this.exchangeLabel = 'GBP'; }
            });
        })
      }.width('100%');

      // 切换方向
      Row() {
        Button('人民币 → 外币').fontSize(12).width('48%').height(30).borderRadius(15)
          .fontColor(this.exchangeMode ? '#FFFFFF' : '#999999')
          .backgroundColor(this.exchangeMode ? '#F4A9AA' : '#F5F5F5')
          .onClick(() => { this.exchangeMode = true; });
        Button('外币 → 人民币').fontSize(12).width('48%').height(30).borderRadius(15)
          .fontColor(!this.exchangeMode ? '#FFFFFF' : '#999999')
          .backgroundColor(!this.exchangeMode ? '#F4A9AA' : '#F5F5F5')
          .onClick(() => { this.exchangeMode = false; });
      }.width('100%');

      Text('1 ' + this.exchangeLabel + ' = ¥ ' + this.exchangeRate.toFixed(4))
        .fontSize(13).fontColor('#BCC2C3').width('100%');

      TextInput({ placeholder: this.exchangeMode ? '输入人民币金额' : '输入' + this.exchangeCurrency + '金额' })
        .type(InputType.Number)
        .onChange((v: string) => {
          const num = parseFloat(v);
          if (this.exchangeMode) {
            this.cnyAmount = v;
            this.usdAmount = isNaN(num) ? '' : (num / this.exchangeRate).toFixed(2);
          } else {
            this.usdAmount = v;
            this.cnyAmount = isNaN(num) ? '' : (num * this.exchangeRate).toFixed(2);
          }
        })
        .width('100%').height(48).borderRadius(12)
        .backgroundColor('#F5F5F5').padding({ left: 16 })
        .fontColor('#3A3A3A');

      Row() {
        Text(this.exchangeMode ? ('💱 ' + this.exchangeCurrency) : '💱 人民币').fontSize(14).fontColor('#999999');
        Blank();
        Text(this.exchangeMode ? (this.usdAmount + ' ' + this.exchangeLabel) : ('¥ ' + this.cnyAmount))
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
      }
      .width('100%').padding(15).backgroundColor('#FFF5F5').borderRadius(12);
    }
    .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16);
  }

  @Builder
  SalaryDialog() {
    Column({ space: 12 }) {
      Row() {
        Text('💼 薪水计算').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A');
        Blank();
        Button('✕').fontSize(14).width(28).height(28)
          .fontColor('#999999').backgroundColor('#F5F5F5').borderRadius(14)
          .onClick(() => { this.showSalary = false; });
      }.width('100%');

      Text('广州市新税法 · 五险一金').fontSize(12).fontColor('#BCC2C3').width('100%');

      TextInput({ placeholder: '输入税前月薪（元）' })
        .type(InputType.Number)
        .onChange((v: string) => {
          this.salaryInput = v;
          const salary = parseFloat(v);
          if (isNaN(salary) || salary <= 0) {
            this.salaryResult = ''; this.taxAmount = ''; this.socialAmount = '';
            return;
          }
          // 五险一金（广州比例简化）
          const pension = salary * 0.08;    // 养老 8%
          const medical = salary * 0.02;    // 医疗 2%
          const unemployment = salary * 0.002; // 失业 0.2%
          const housing = salary * 0.05;    // 公积金 5%（最低档）
          const socialTotal = pension + medical + unemployment + housing;
          this.socialAmount = socialTotal.toFixed(2);

          // 应纳税所得额
          const taxable = salary - socialTotal - 5000;
          let tax = 0;
          if (taxable > 0) {
            if (taxable <= 3000) { tax = taxable * 0.03; }
            else if (taxable <= 12000) { tax = taxable * 0.1 - 210; }
            else if (taxable <= 25000) { tax = taxable * 0.2 - 1410; }
            else if (taxable <= 35000) { tax = taxable * 0.25 - 2660; }
            else if (taxable <= 55000) { tax = taxable * 0.3 - 4410; }
            else if (taxable <= 80000) { tax = taxable * 0.35 - 7160; }
            else { tax = taxable * 0.45 - 15160; }
          }
          this.taxAmount = tax.toFixed(2);
          this.salaryResult = (salary - socialTotal - tax).toFixed(2);
        })
        .width('100%').height(48).borderRadius(12)
        .backgroundColor('#F5F5F5').padding({ left: 16 })
        .fontColor('#3A3A3A');

      if (this.salaryResult !== '') {
        Column({ space: 8 }) {
          Row() {
            Text('税后工资').fontSize(14).fontColor('#999999');
            Blank();
            Text('¥ ' + this.salaryResult).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#F4A9AA');
          }.width('100%').padding(12).backgroundColor('#FFF5F5').borderRadius(10);

          Row() {
            Text('个人所得税').fontSize(13).fontColor('#999999');
            Blank();
            Text('¥ ' + this.taxAmount).fontSize(14).fontColor('#E38A8B');
          }.width('100%');

          Row() {
            Text('五险一金').fontSize(13).fontColor('#999999');
            Blank();
            Text('¥ ' + this.socialAmount).fontSize(14).fontColor('#999999');
          }.width('100%');
        }
        .width('100%').margin({ top: 5 });
      }
    }
    .width('85%').padding(20).backgroundColor('#FFFFFF').borderRadius(16);
  }

  build() {
    Stack() {
      Column() {
        if (this.currentTab === 0) {
          Scroll() { this.HomePage(); }.width('100%').layoutWeight(1);
        } else if (this.currentTab === 1) {
          Scroll() { this.ReportPage(); }.width('100%').layoutWeight(1);
        } else {
          Scroll() { this.MinePage(); }.width('100%').layoutWeight(1);
        }

        Row() {
          Button('首页').layoutWeight(1).height(50).fontSize(14)
            .fontColor(this.currentTab === 0 ? '#F4A9AA' : '#999999')
            .backgroundColor('#FAFAFA').borderRadius(0)
            .onClick(() => { this.currentTab = 0; });
          Button('报表').layoutWeight(1).height(50).fontSize(14)
            .fontColor(this.currentTab === 1 ? '#F4A9AA' : '#999999')
            .backgroundColor('#FAFAFA').borderRadius(0)
            .onClick(() => { this.currentTab = 1; });
          Button('我的').layoutWeight(1).height(50).fontSize(14)
            .fontColor(this.currentTab === 2 ? '#F4A9AA' : '#999999')
            .backgroundColor('#FAFAFA').borderRadius(0)
            .onClick(() => { this.currentTab = 2; });
        }.width('100%').height(50).backgroundColor('#FAFAFA');
      }
      .width('100%').height('100%');

      if (this.showCalendar) {
        Column() {
          this.CalendarDialog();
        }
        .width('100%').height('100%').backgroundColor('#00000050')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showCalendar = false; });
      }
      if (this.showShopping) {
        Column() {
          this.ShoppingDialog();
        }
        .width('100%').height('100%').backgroundColor('#00000050')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showShopping = false; });
      }
      if (this.showExchange) {
        Column() {
          this.ExchangeDialog();
        }
        .width('100%').height('100%').backgroundColor('#00000050')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showExchange = false; });
      }
      if (this.showSalary) {
        Column() {
          this.SalaryDialog();
        }
        .width('100%').height('100%').backgroundColor('#00000050')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showSalary = false; });
      }
    }
    .width('100%').height('100%').backgroundColor('#FFF5F5');
  }
}