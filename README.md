# MakingMoney
pytrader.py,Kiwoom,pytrader.ui,buy,sell_list가 메인코드입니다!

Update pytrader.py
0902
코스닥에 모든 종목들을 실시간 등록을 하는 것을 구현했다. 
자동매수는 _handler_real_data에서 모두 처리할 생각이다. sell_list update와 동시에 주문을 넣을 것이다. 그리고 넣은후에 바로 업데이트 
매도는 아마 실시간 잔고조회에 할 것이다.
 master

0905
현재 init위 On리시브 리얼과 과거 거래량을 가져오는 함수끼리 이벤트
충돌로 인해 에러가 납니다. 아마 장시간 이후에 cal_df를 파일로 저장한후 그냥 그 파일을 읽어서
거래량 비교로 실행해야합니다
핸들러안의
SetRealReg 에 인자로 코드로 보낼때 codl=[] codl.append(code)로 리스트로 변환해서 인자값을 넣어야합니다.

