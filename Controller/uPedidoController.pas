unit uPedidoController;

interface

uses
  Horse, System.JSON, System.SysUtils, uPedidoRepository;

type
  TPedidoController = class
  public
    class procedure RegistrarRotas;
    class procedure ReceberPedido(Req: THorseRequest; Res: THorseResponse);
  end;

implementation

{ TPedidoController }

class procedure TPedidoController.RegistrarRotas;
begin
  // Mapeia a rota POST /pedidos para o método ReceberPedido
  THorse.Post('/pedidos', ReceberPedido);
end;

class procedure TPedidoController.ReceberPedido(Req: THorseRequest; Res: THorseResponse);
var
  JSONBody: TJSONObject;
  Retorno: TJSONObject;
  Repositorio: TPedidoRepository;
begin
  try
    // Pega o JSON enviado pelo celular
    JSONBody := Req.Body<TJSONObject>;

    // Instancia o repositório e manda salvar
    Repositorio := TPedidoRepository.Create;
    try
      Repositorio.GravarPedido(JSONBody);
    finally
      Repositorio.Free;
    end;

    // Responde sucesso para o celular
    Retorno := TJSONObject.Create;
    Retorno.AddPair('status', 'sucesso');
    Retorno.AddPair('mensagem', 'Pedido integrado com sucesso no DBF!');

    Res.Status(THTTPStatus.Created).Send(Retorno);

  except
    on E: Exception do
    begin
      Retorno := TJSONObject.Create;
      Retorno.AddPair('erro', 'Falha ao processar pedido: ' + E.Message);
      Res.Status(THTTPStatus.InternalServerError).Send(Retorno);
    end;
  end;
end;

end.
