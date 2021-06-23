module top 
#(
        parameter integer USB_SEND_WIDTH      = 512,
        parameter integer USB_REVE_WIDTH      = 512,
        parameter integer USB_PORT_WIDTH      = 8
)(        
    //USBӲ���ӿ�
    input  wire                         usb_reset,          //(ALL RST):USB��λ
    input  wire                         usb_clock,          //(CLKOUT):USBʱ�Ӷ˿ڣ�USBģ���ṩ��60MHZ��
    inout  wire [USB_PORT_WIDTH -1 :0]  usb_ports,          //(D0-D7):USB���ݶ˿�
    //output reg [USB_PORT_WIDTH -1 :0]   usb_ports,          //(D0-D7):USB���ݶ˿�
    output reg                          usb_read_n,         //(RD#):USB��ȡʹ�ܶ˿�
    output reg                          usb_write_n,        //(WR#):USBд��ʹ�ܶ˿�
    input  wire                         usb_rx_empty,       //(RXF#):USB���տն˿�
    input  wire                         usb_tx_full,        //(TXE#):USB�������˿�
    output reg                          usb_sendimm_n,      //(SIWV#):USB�������Ͷ˿�
    output reg                          usb_outen_n        //(OE#):USB���ʹ�ܶ˿�
    //USBģ��ӿ�
//    input  wire [USB_SEND_WIDTH -1 :0]  usb_send,          //USB���ݷ��Ϳ�
//    input  wire                         usb_en,            //USBʹ�ܶ˿�
//    output reg                          usb_vaild,         //USB������Ч
//    output reg  [USB_REVE_WIDTH -1 :0]  usb_reve           //USB���ݽ��տ�
);
//��������
localparam  USB_STATE_SEND    =   1'b1;                 //USB����״̬
localparam  USB_STATE_REVE    =   1'b0;                 //USB����״̬
localparam  USB_SEND_MAX      =   USB_SEND_WIDTH/8;    //��������������
localparam  USB_REVE_MAX      =   USB_REVE_WIDTH/8 +3; //��������������

//���ݶ���
reg [  7:0] usb_cache;                           //USB���ͼĴ���
reg         usb_state;                          //USB״̬�Ĵ���
reg [ 15:0] usb_reve_count;                     //���ռ���
reg [ 15:0] usb_send_count;                     //���ͼ���

//USBģ��ӿ�
reg  [USB_SEND_WIDTH -1 :0]  usb_send;          //USB���ݷ��Ϳ�
reg                          usb_en;            //USBʹ�ܶ˿�
reg                          usb_vaild;         //USB������Ч
reg  [USB_REVE_WIDTH -1 :0]  usb_reve;          //USB���ݽ��տ�


//USBӲ���˿ڣ�����״̬=���ͻ��棻����״̬=����̬��
assign usb_ports = (usb_state == USB_STATE_SEND) ? usb_cache : 8'hZZ;


//USB״̬�л�
//always @(posedge usb_clock, negedge usb_reset) 
//begin
//    if(!usb_reset)
//       usb_state <=  USB_STATE_SEND;
////    else if(usb_en == 1'b1)
////       usb_state <=  USB_STATE_SEND; 
////    else if(usb_send_count == USB_SEND_MAX)
////       usb_state <=  USB_STATE_REVE;
//end

//USB״̬�л�
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
       usb_state <=  USB_STATE_REVE;
    else if(usb_vaild == 1'b1)
    begin
       usb_state <=  USB_STATE_SEND; 
       usb_send <= usb_reve;
    end
    else if(usb_send_count == USB_SEND_MAX)
       usb_state <=  USB_STATE_REVE;
end


//USB���ͼ���
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
       usb_send_count <= 16'b0; 
    else if(usb_state ==  USB_STATE_SEND && !usb_tx_full && usb_send_count < USB_SEND_MAX)
       usb_send_count <= usb_send_count + 16'd1;
    else if(usb_send_count == USB_SEND_MAX)
       usb_send_count <= 16'b0;
end
//����д������
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
    begin
        usb_write_n <= 1'b1;
        usb_cache[7:0] <= 8'b0;
    end
    else if(usb_state ==  USB_STATE_SEND && !usb_tx_full && usb_send_count > 16'd0)
    begin
        usb_write_n <= 1'b0;
        usb_cache[7:0] <= usb_send[((usb_send_count-1)*8+7) -: 8]; 
    end
    else  
    begin
        usb_write_n <= 1'b1;
        usb_cache[7:0] <= 8'b0; 
    end  
end



//USB���ռ���
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
       usb_reve_count <= 16'b0; 
    else if(usb_state ==  USB_STATE_REVE && !usb_rx_empty && usb_reve_count < USB_REVE_MAX)
       usb_reve_count <= usb_reve_count + 16'b1;
    else if(usb_reve_count == USB_REVE_MAX) 
       usb_reve_count <= 16'b0;
end
//���ո�ֵ
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
        usb_reve[511:0] <= 512'b0; 
    else if(usb_state ==  USB_STATE_REVE && !usb_rx_empty && usb_reve_count > 16'd2)
        usb_reve[((usb_reve_count-3)*8+7) -: 8] <= usb_ports[7:0]; 
end
//�������֪ͨ
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
        usb_vaild <= 1'b0;
    else if(usb_reve_count == USB_REVE_MAX) 
        usb_vaild <= 1'b1;
    else usb_vaild <= 1'b0;   
end
//���ն�ȡ����
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
        usb_read_n <= 1'b1;
    else if(usb_state ==  USB_STATE_REVE && !usb_rx_empty && usb_reve_count > 16'd1)
        usb_read_n <= 1'b0;
    else usb_read_n <= 1'b1;
end
//�������ʹ�ܿ���
always @(posedge usb_clock, negedge usb_reset) 
begin
    if(!usb_reset)
        usb_outen_n <= 1'b1;
    else if(usb_state ==  USB_STATE_REVE && usb_reve_count == 16'd1)
        usb_outen_n <= 1'b0;
    else if(usb_reve_count == USB_REVE_MAX)
        usb_outen_n <= 1'b1;   
end

endmodule