unit uPedidoRepository;

interface

uses
  System.JSON, System.SysUtils, uConexaoDBF;

type
  TPedidoRepository = class
  private
    function GerarNumeroPedido: string;
  public
    // Recebe o JSON do pedido e grava nas tabelas DBF
    procedure GravarPedido(AJSONPedido: TJSONObject);
  end;

implementation

{ TPedidoRepository }

function TPedidoRepository.GerarNumeroPedido: string;
begin
  // Gera um número simples baseado na data/hora para o exemplo (ex: 2608153012)
  Result := FormatDateTime('ddhhnnsszz', Now);
end;

procedure TPedidoRepository.GravarPedido(AJSONPedido: TJSONObject);
var
  DBF: TConexaoDBF;
  NumeroPedido, Cliente, SqlMaster, SqlItem: string;
  Total: Double;
  Itens: TJSONArray;
  Item: TJSONValue;
  I: Integer;
begin
  DBF := TConexaoDBF.Create;
  try
    // Inicia controle de transação manual se necessário, aqui faremos direto
    NumeroPedido := GerarNumeroPedido;
    Cliente := AJSONPedido.GetValue<string>('cliente', 'CLIENTE PADRAO');
    Total := AJSONPedido.GetValue<Double>('total', 0);

    // 1. Grava a Capa do Pedido (PEDDLV)
    SqlMaster := Format(
      'INSERT INTO PEDDLV (NR_PEDIDO, DT_PEDIDO, NM_CLIENTE, VL_TOTAL, DS_STATUS) ' +
      'VALUES (%s, Date(), %s, %s, %s)',
      [QuotedStr(NumeroPedido), QuotedStr(Cliente), FloatToStr(Total).Replace(',', '.'), QuotedStr('ABERTO')]
    );
    DBF.Conexao.ExecSQL(SqlMaster);

    // 2. Grava os Itens do Pedido (PEDDLVIT)
    if AJSONPedido.TryGetValue<TJSONArray>('itens', Itens) then
    begin
      for I := 0 to Itens.Count - 1 do
      begin
        Item := Itens.Items[I];

        SqlItem := Format(
          'INSERT INTO PEDDLVIT (NR_PEDIDO, NR_ITEM, CD_PRODUTO, QT_PRODUTO, VL_UNITARI) ' +
          'VALUES (%s, %s, %s, %s, %s)',
          [
            QuotedStr(NumeroPedido),
            QuotedStr(FormatFloat('000', I + 1)),
            QuotedStr(Item.GetValue<string>('produto', '000')),
            FloatToStr(Item.GetValue<Double>('qtde', 1)).Replace(',', '.'),
            FloatToStr(Item.GetValue<Double>('vl_unit', 0)).Replace(',', '.')
          ]
        );
        DBF.Conexao.ExecSQL(SqlItem);
      end;
    end;

  finally
    DBF.Free;
  end;
end;

end.
