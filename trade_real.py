import sys
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5 import uic
from Kiwoom import *
import time
# pymon 추가
from pandas import DataFrame
import datetime
import re
import csv #csv 파일 읽기

# import type
# import updown
MARKET_KOSPI = 0
MARKET_KOSDAQ = 10

# ui 파일을 불러오는 코드
form_class = uic.loadUiType("pytrader.ui")[0]


class MyWindow(QMainWindow, form_class):
    def __init__(self):
        super().__init__()
        self.setupUi(self)

        self.trade_stocks_done = False

        self.kiwoom = Kiwoom()
        self.kiwoom.comm_connect()
        #----------------
        '''
        self.kiwoom.GetConditionLoad()

        # 전체 조건식 리스트 얻기
        conditions = self.kiwoom.GetConditionNameList()

        # 0번 조건식에 해당하는 종목 리스트 출력
        condition_index = conditions[0][0]
        condition_name = conditions[0][1]
        codes = self.kiwoom.SendCondition("0101", condition_name, condition_index, 0)
        print(codes)
        self.update_buy_list(codes)
        '''
        #---------------------
        self.get_code_list()
        # self.called() #계속 탐색 위한 과정?
        # self.auto_run()

        self.timer = QTimer(self)
        self.timer.start(1000)
        self.timer.timeout.connect(self.timeout)

        self.timer2 = QTimer(self)
        self.timer2.start(1000 * 10)
        self.timer2.timeout.connect(self.timeout2)
        ##########
        self.OnReceiveRealData.connect(self._handler_real_data)
        '''
        OnReceiveRealData(
          BSTR sCode,        // 종목코드
          BSTR sRealType,    // 실시간타입
          BSTR sRealData    // 실시간 데이터 전문 (사용불가)
          )
          
          실시간시세 데이터가 수신될때마다 종목단위로 발생됩니다.
          SetRealReg()함수로 등록한 실시간 데이터도 이 이벤트로 전달됩니다.
          GetCommRealData()함수를 이용해서 수신된 데이터를 얻을수 있습니다.
          '''
        ##################
        accouns_num = int(self.kiwoom.get_login_info("ACCOUNT_CNT"))
        accounts = self.kiwoom.get_login_info("ACCNO")

        accounts_list = accounts.split(';')[0:accouns_num]
        self.comboBox.addItems(accounts_list)

        self.lineEdit.textChanged.connect(self.code_changed)

        self.pushButton.clicked.connect(self.send_order)  # 주문
        self.pushButton_2.clicked.connect(self.check_balance)
        self.pushButton_3.clicked.connect(self.auto_run)  # 자동매수 프로그램
        self.pushButton_6.clicked.connect(self.load_buy_sell_list)  # 자동매매 선정 리스트
        self.pushButton_7.clicked.connect(self.notTrade)  # 미체결현황
        self.pushButton_7.clicked.connect(self.Trade)  # 체결현황

        self.load_buy_sell_list()  # 기본적인 자동매매 선정리스트 세팅
        # self.notTrade()  # 미체결 현황 실행


###############


    def _handler_real_data(self, code, real_type, data):
        '''OnReceiveRealData()이벤트가 발생될때
        실행되는 함수 GetCommRealData가 들어가야함
        '''
        print(code, real_type, data)
        ##fid에 따라 real_type이 달라짐
        if real_type == "장시작시간":
            gubun =  self.GetCommRealData(code, 215)
            remained_time =  self.GetCommRealData(code, 214)
            print(gubun, remained_time)
        if real_type == "주식시세" :
            '''거래량'''
            vol = self.GetCommRealData(code, 13)
            print(vol)


    def SetRealReg(self, screen_no, code_list, fid_list, real_type):
        self.kiwoom.dynamicCall("SetRealReg(QString, QString, QString, QString)",
                              screen_no, code_list, fid_list, real_type)
        '''
          [SetRealReg() 함수]
          
          SetRealReg(
          BSTR strScreenNo,   // 화면번호
          BSTR strCodeList,   // 종목코드 리스트
          BSTR strFidList,  // 실시간 FID리스트
          BSTR strOptType   // 실시간 등록 타입, 0또는 1
          )
          
          종목코드와 FID 리스트를 이용해서 실시간 시세를 등록하는 함수입니다.
          한번에 등록가능한 종목과 FID갯수는 100종목, 100개 입니다.
          실시간 등록타입을 0으로 설정하면 등록한 종목들은 실시간 해지되고 등록한 종목만 실시간 시세가 등록됩니다.
          실시간 등록타입을 1로 설정하면 먼저 등록한 종목들과 함께 실시간 시세가 등록됩니다
          '''

    def GetCommRealData(self, code, fid):
        data = self.kiwoom.dynamicCall("GetCommRealData(QString, int)", code, fid)
        return data
    ''' GetCommRealData(
          BSTR strCode,   // 종목코드
          long nFid   // 실시간 타입에 포함된FID (Feild ID)
          )
          
          실시간시세 데이터 수신 이벤트인 OnReceiveRealData() 가 발생될때 실시간데이터를 얻어오는 함수입니다.
          이 함수는 OnReceiveRealData()이벤트가 발생될때 그 안에서 사용해야 합니다.
          FID 값은 "실시간목록"에서 확인할 수 있습니다.
          
           strRealData = OpenAPI.GetCommRealData(strCode, 13);   // 누적거래량
           
           Real Type : 주식시세

	[10] = 현재가
	[11] = 전일대비
	[12] = 등락율
	[27] = (최우선)매도호가
	[28] = (최우선)매수호가
	[13] = 누적거래량
	[14] = 누적거래대금
	[16] = 시가
	[17] = 고가
	[18] = 저가
	[25] = 전일대비기호
	[26] = 전일거래량대비(계약,주)
	[29] = 거래대금증감
	[30] = 전일거래량대비(비율)
	[31] = 거래회전율
	[32] = 거래비용
	[311] = 시가총액(억)
	[567] = 상한가발생시간
	[568] = 하한가발생시간
    '''


    def check_speedy_rising_volume(self, code,i):
        '''SetRealReg(self, screen_no, code_list, fid_list, real_type)'''
        screen_no = i % 100
        volumes = self.SetRealReg(screen_no,code,"13",1)

        if len(volumes) < 11:
            return False

        sum_vol20 = 0
        today_vol = 0

        for i, vol in enumerate(volumes):
            if i == 0:
                today_vol = vol
            elif 1 <= i <= 10:
                sum_vol20 += vol
            else:
                break

        avg_vol20 = sum_vol20 / 10
        if today_vol > avg_vol20 * 5:
            return True
#################


    # 코드 리스트 받아오기
    def get_code_list(self):
        self.kospi_codes = self.kiwoom.get_code_list_by_market(MARKET_KOSPI)
        self.kosdaq_codes = self.kiwoom.get_code_list_by_market(MARKET_KOSDAQ)

    def get_ohlcv(self, code, start):
        self.kiwoom.ohlcv = {'date': [], 'open': [], 'high': [], 'low': [], 'close': [], 'volume': []}

        self.kiwoom.set_input_value("종목코드", code)
        self.kiwoom.set_input_value("기준일자", start)
        self.kiwoom.set_input_value("수정주가구분", 1)
        self.kiwoom.comm_rq_data("opt10081_req", "opt10081", 0, "0101")
        # time.sleep(0.5)

        df = DataFrame(self.kiwoom.ohlcv, columns=['open', 'high', 'low', 'close', 'volume'],
                       index=self.kiwoom.ohlcv['date'])
        return df

    # 급등주 포착 알고리즘, 매수
    def check_speedy_rising_volume(self, code):
        today = datetime.datetime.today().strftime("%Y%m%d")
        df = self.get_ohlcv(code, today)
        volumes = df['volume']

        if len(volumes) < 11:
            return False

        sum_vol20 = 0
        today_vol = 0

        for i, vol in enumerate(volumes):
            if i == 0:
                today_vol = vol
            elif 1 <= i <= 10:
                sum_vol20 += vol
            else:
                break

        avg_vol20 = sum_vol20 / 10
        if today_vol > avg_vol20 * 5:
            return True

    def check_up(self):
        #code는 비율에 성립하는지 비교해보는 코드
        #sell_write=[] #이건 그냥 매도에 쓸 내용
        #이건 잔고 현황 가져오는 것
        print('진입여부')
        self.kiwoom.reset_opw00018_output()
        account_number = self.kiwoom.get_login_info("ACCNO")
        account_number = account_number.split(';')[0]

        self.kiwoom.set_input_value("계좌번호", account_number)
        self.kiwoom.comm_rq_data("opw00018_req", "opw00018", 0, "2000")

        while self.kiwoom.remained_data:
            # time.sleep(0.5)
            self.kiwoom.set_input_value("계좌번호", account_number)
            self.kiwoom.comm_rq_data("opw00018_req", "opw00018", 2, "2000")
        item_count = len(self.kiwoom.opw00018_output['multi'])
        print('여기 while문')
        #print('여기까지 안오나?')
        #여기는 코드 네임 가져오는 것
        #f=open('code_name.csv', 'r',encoding='utf-8-sig')
        #read=csv.reader(f)
        #reads=list(read) #그냥 상태일 때는 이것도 안나오고.....
        #print(reads)
        #print('이 파일 리스트 변환 에러임?')
        #global message
        #-----------여기까지는 에러가 없음.
        #code_name=[]
        #print(code_name)
        sell_list=[]
        sell_lists=[]
        #print('아이템 진입')
        for j in range(item_count): #이건 아이템 전체 줄
            row = self.kiwoom.opw00018_output['multi'][j]#여기는 각 줄에 대한 내용
            type_code=row[0]
            name=row[1] #종목명
            profit=row[6] #수익률
            #print(type_code,name,profit) #여기까지는 문제가 없는 것 같다.
            #print(float(profit))
            if float(profit)>(-10.0): #이건 작동 여부 위해서 설정한 거고 필요에 따라 변경
                #print(type_code, name)
                sell_list.append(type_code)
        #print('아이템 정리')
        #print(code_name)
        #print('수익률 판단 후')
        for i in sell_list:
            n=re.sub(",","",i)
            sell_lists.append(n)
        '''
        for i in range(len(code_name)):
            print(code_name[i]) #아래 for 문에서 문제가 있는듯.
            for line in reads:
                if code_name[i] in line[1]:
                    sell_list.append(line[0])
                    break
        '''
        #sell_list=sell_lists
        print(sell_lists)
        #f.close()
        self.update_sell_list(sell_lists)
        time.sleep(0.5)
        self.trade_stocks_done = False
        self.timeout()
        sell_lists.clear()
        #update_sell_list(sell_list)
        return True

        '''
        if message=='True':
            return True
        else:
            return False
        '''

    '''
    def check_up(self,code):
        print('매도 알고리즘 진입')
        today = datetime.datetime.today().strftime("%Y%m%d")
        df = self.get_ohlcv(code, today)
        closes = df['close']
        #비교 단위를 현재가로 5일간 비교
        if len(closes) < 6:
            return False

        sum_cls5 = 0
        today_cls = 0

        for i, cls in enumerate(closes):
            if i == 0:
                today_cls = cls
            elif 1 <= i <= 5:
                sum_cls5 += cls
            else:
                break
        avg_cls5=sum_cls5/5
        #구매 가격 가져오기
        f = open("sb_list.txt", 'rt', encoding='utf-8')
        sell_list = f.readlines()
        f.close()
        buy_price=0
        for row_data in sell_list:
            split_row_data = row_data.split(';')
            codes = split_row_data[1]
            buy_prices = split_row_data[6].strip()
            if codes==code:
                buy_price=buy_prices
        if today_cls>avg_cls5*5 and today_cls>buy_price:
            return True
    '''
    def update_buy_list(self, buy_list):
        f = open("buy_list.txt", "a+", encoding='utf-8')
        for code in buy_list:
            line = "매수;" + code + ";시장가;1;0;매수전" + "\n"
            f.writelines(line)
        f.close()
    def update_sell_list(self, sell_list):
        f = open("sell_list.txt", "a+", encoding='utf-8')
        for code in sell_list:
            line = "매도;" + code + ";시장가;1;0;매도전" + "\n"
            f.writelines(line)
        f.close()

    # 자동매매 자동 호출 시스템
    def auto_run(self):
        buy_list = []
        num = len(self.kosdaq_codes)
        #sell_list = []
        for i, code in enumerate(self.kosdaq_codes):
            print(i, '/', num)
            # 매수 알고리즘
            if self.check_kosdaq_cal(code, i):
                buy_list.append(code)
                # 확인 차원 출력, 나중에 삭제 예정
                print("급등주: ", code)
                self.update_buy_list(buy_list)
                time.sleep(0.5)
                self.trade_stocks_done = False
                self.timeout()
            buy_list.clear()
            time.sleep(3.6)
            # 매도 알고리즘, 이걸 코드 실행 기준을 파일 내에 있다고 할 때 해야 하나. 난감.
            #print('중간')
            #sell_list=self.check_up
            if self.check_up():
                print("여기")
                #time.sleep(0.5)
                #self.trade_stocks_done = False
                #self.timeout()
            #time.sleep(0.5)
            #print("상승주: ",sell_list)

            #self.update_sell_list(sell_list)
            #print('매도 알고리즘 내 진입')
            time.sleep(3.6)
            print("끝")

    # -------------------------------------

    # 트레이딩 관련 텍스트 파일 읽어주기
    def trade_stocks(self):
        # print('here1')
        hoga_lookup = {'지정가': "00", '시장가': "03"}

        f = open("buy_list.txt", 'rt', encoding='utf-8')
        buy_list = f.readlines()
        f.close()

        f = open("sell_list.txt", 'rt', encoding='utf-8')
        sell_list = f.readlines()
        f.close()

        # account
        account = self.comboBox.currentText()

        # buy list
        for row_data in buy_list:
            split_row_data = row_data.split(';')
            hoga = split_row_data[2]
            code = split_row_data[1]
            num = split_row_data[3]
            price = split_row_data[4]
            buy = split_row_data[5].strip()
            # print(buy)
            time.sleep(0.5)
            if buy == '매수전':
                # print("매수 전 진입") #정상적으로 한번 진입하는 것을 확인
                self.kiwoom.send_order("send_order_req", "0101", account, 1, code, num, price, hoga_lookup[hoga], "")
        # sell list
        for row_data in sell_list:
            split_row_data = row_data.split(';')
            hoga = split_row_data[2]
            code = split_row_data[1]
            num = split_row_data[3]
            price = split_row_data[4]
            buy_price = split_row_data[6]
            buy = split_row_data[5].strip()
            # print(buy)
            time.sleep(0.5)
            if buy == '매도전':
                print("매도 전 진입")
                #매도 주문 하기 위해 현재가를 비교하고 나서 주문넣기
                self.kiwoom.send_order("send_order_req", "0101", account, 1, code, num, price, hoga_lookup[hoga], "")
        # buy list
        # 여기는 여러번 진입하긴 하는데 실제로는 바꾸는 거기에 상관이 없을 것 같음.
        for i, row_data in enumerate(buy_list):
            buy_list[i] = buy_list[i].replace("매수전", "주문완료")
            self.trade_stocks_done = False
        #sell list
        for i, row_data in enumerate(sell_list):
            sell_list[i] = sell_list[i].replace("매도전", "주문완료")
            self.trade_stocks_done = False

        # file update
        f = open("buy_list.txt", 'wt', encoding='utf-8')
        for row_data in buy_list:
            f.write(row_data)
        f.close()

        # sell list, 여기도 바꿔야 하는데
        '''        
        for i, row_data in enumerate(sell_list):
            sell_list[i] = sell_list[i].replace("매도전", "주문완료")
        '''

        # file update
        f = open("sell_list.txt", 'wt', encoding='utf-8')
        for row_data in sell_list:
            f.write(row_data)
        f.close()

    # 트레이딩 관련 파일 로드
    def load_buy_sell_list(self):
        f = open("buy_list.txt", 'rt', encoding='utf-8')
        # f = open("buy_list.txt", 'rt', encoding='euc-kr')
        buy_list = f.readlines()
        f.close()

        f = open("sell_list.txt", 'rt', encoding='utf-8')
        # f = open("sell_list.txt", 'rt', encoding='euc-kr')
        sell_list = f.readlines()
        f.close()

        row_count = len(buy_list) + len(sell_list)
        self.tableWidget_3.setRowCount(row_count)
        # print(buy_list)
        # buy list
        for j in range(len(buy_list)):
            row_data = buy_list[j]
            split_row_data = row_data.split(';')
            split_row_data[1] = self.kiwoom.get_master_code_name(split_row_data[1].rsplit())

            for i in range(len(split_row_data)):
                item = QTableWidgetItem(split_row_data[i].rstrip())
                #item.setTextAlignment(Qt.AlignVCenter | Qt.AlignCenter)
                self.tableWidget_3.setItem(j, i, item)

        # sell list
        for j in range(len(sell_list)):
            row_data = sell_list[j]
            split_row_data = row_data.split(';')
            split_row_data[1] = self.kiwoom.get_master_code_name(split_row_data[1].rstrip())

            for i in range(len(split_row_data)):
                item = QTableWidgetItem(split_row_data[i].rstrip())
                #item.setTextAlignment(Qt.AlignVCenter | Qt.AlignCenter)
                self.tableWidget_3.setItem(len(buy_list) + j, i, item)

        self.tableWidget_3.resizeRowsToContents()

    def code_changed(self):
        code = self.lineEdit.text()
        name = self.kiwoom.get_master_code_name(code)
        self.lineEdit_2.setText(name)

    # 주문 전송
    def send_order(self):
        order_type_lookup = {'신규매수': 1, '신규매도': 2, '매수취소': 3, '매도취소': 4}
        hoga_lookup = {'지정가': "00", '시장가': "03"}

        account = self.comboBox.currentText()
        order_type = self.comboBox_2.currentText()
        code = self.lineEdit.text()
        hoga = self.comboBox_3.currentText()
        num = self.spinBox.value()
        price = self.spinBox_2.value()

        self.kiwoom.send_order("send_order_req", "0101", account, order_type_lookup[order_type], code, num, price,
                               hoga_lookup[hoga], "")
        # time.sleep(0.5)

    # 타임아웃 코드
    def timeout(self):
        # 여기까지는 진입하는데.....
        market_start_time = QTime(9, 0, 0)
        market_end_time = QTime(15, 30, 0)
        current_time = QTime.currentTime()
        # print(current_time)
        # print(current_time, self.trade_stocks_done) #이건 작동 여부 보려고
        if current_time > market_start_time and current_time<market_end_time and self.trade_stocks_done == False:
            # 일단 여기서 확인해본바로는 마켓시간이 안맞는것 같아서 and를 or로 바꾸고 해봄.
            # print('here') #여기는 장시간에 해야되어서.... 진입 여부 확인용
            self.trade_stocks()  # 여기가 안되는 것 같다.
            self.trade_stocks_done = True
        #elif current_time>market_end_time or current_time<market_start_time:
            #print("현재는 주문 가능한 시간이 아닙니다.")

        text_time = current_time.toString("hh:mm:ss")
        time_msg = "현재시간: " + text_time

        state = self.kiwoom.get_connect_state()
        if state == 1:
            state_msg = "서버 연결 중"
        else:
            state_msg = "서버 미 연결 중"

        self.statusbar.showMessage(state_msg + " | " + time_msg)
        # 여기까지는 오류 없이 온다는 얘긴데

    # 체크박스 타임아웃
    def timeout2(self):
        if self.checkBox.isChecked():
            self.check_balance()

    # 정보 작성?
    def check_balance(self):
        self.kiwoom.reset_opw00018_output()
        account_number = self.kiwoom.get_login_info("ACCNO")
        account_number = account_number.split(';')[0]

        self.kiwoom.set_input_value("계좌번호", account_number)
        self.kiwoom.comm_rq_data("opw00018_req", "opw00018", 0, "2000")

        while self.kiwoom.remained_data:
            # time.sleep(0.5)
            self.kiwoom.set_input_value("계좌번호", account_number)
            self.kiwoom.comm_rq_data("opw00018_req", "opw00018", 2, "2000")

        # opw00001
        self.kiwoom.set_input_value("계좌번호", account_number)
        self.kiwoom.comm_rq_data("opw00001_req", "opw00001", 0, "2000")

        # balance
        item = QTableWidgetItem(self.kiwoom.d2_deposit)
        # item.setTextAlignment(Qt.AlignVCenter | Qt.AlignRight)
        self.tableWidget.setItem(0, 0, item)

        for i in range(1, 6):
            item = QTableWidgetItem(self.kiwoom.opw00018_output['single'][i - 1])
            # item.setTextAlignment(Qt.AlignVCenter | Qt.AlignRight)
            self.tableWidget.setItem(0, i, item)

        self.tableWidget.resizeRowsToContents()

        # Item list
        item_count = len(self.kiwoom.opw00018_output['multi'])
        # auto_profit(item_count)
        self.tableWidget_2.setRowCount(item_count)

        for j in range(item_count):
            row = self.kiwoom.opw00018_output['multi'][j]
            for i in range(len(row)):
                item = QTableWidgetItem(row[i])
                # item.setTextAlignment(Qt.AlignVCenter | Qt.AlignRight)
                self.tableWidget_2.setItem(j, i, item)

        self.tableWidget_2.resizeRowsToContents()

    # 미체결 현황 조회, nt_list.txt, 이제 주문 들어가면 미체결, 체결 알림시 삭제
    def notTrade(self):
        print('not trade 진입')

    #체결 현황 조회, t_list.txt, 체결 알림이 뜨게 되면 추가를 해줌. 날짜 다르면 삭제 기능도?
    def Trade(self):
        time.sleep(5)
        print('trade 진입')


if __name__ == "__main__":
    app = QApplication(sys.argv)
    myWindow = MyWindow()
    myWindow.show()
    app.exec_()
    # myWindow.run()