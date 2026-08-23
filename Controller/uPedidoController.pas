unit uPedidoController;

interface

uses
  Horse, System.JSON, System.SysUtils, uPedidoRepository;

type
  TPedidoController = class
  public
    class procedure RegistrarRotas;
    class procedure ReceberPedido(Req: THorseRequest; Res: THorseResponse);

    // 1. A declaração da função que vai listar os produtos
    class procedure ListarProdutos(Req: THorseRequest; Res: THorseResponse);
  end;

implementation

{ TPedidoController }

class procedure TPedidoController.RegistrarRotas;
begin
  // Mapeia a rota POST para gravar pedido
  THorse.Post('/pedidos', ReceberPedido);

  // Mapeia a rota GET para listar produtos
  THorse.Get('/produtos', ListarProdutos);
end;

class procedure TPedidoController.ListarProdutos(Req: THorseRequest; Res: THorseResponse);
var
  Repositorio: TPedidoRepository;
begin
  Repositorio := TPedidoRepository.Create;
  try
    // 2. A implementação que chama o banco e devolve o JSON
    Res.Status(THTTPStatus.OK).Send(Repositorio.ListarProdutos);
  finally
    Repositorio.Free;
  end;
end;

class procedure TPedidoController.ReceberPedido(Req: THorseRequest; Res: THorseResponse);
var
  JSONBody: TJSONObject;
  Retorno: TJSONObject;
  Repositorio: TPedidoRepository;
begin
  try
    JSONBody := Req.Body<TJSONObject>;
    Repositorio := TPedidoRepository.Create;
    try
      Repositorio.GravarPedido(JSONBody);
    finally
      Repositorio.Free;
    end;

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
