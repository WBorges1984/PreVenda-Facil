unit uPedidoController;

interface

uses
  Horse, System.JSON, System.SysUtils, uPedidoRepository,
  uConexaoDBF, FireDAC.Comp.Client, Data.DB; // Adicionado aqui para o banco!

type
  TPedidoController = class
  public
    class procedure RegistrarRotas;
    class procedure ReceberPedido(Req: THorseRequest; Res: THorseResponse);
    class procedure ListarProdutos(Req: THorseRequest; Res: THorseResponse);

    // A declaração que estava faltando:
    class procedure FazerLogin(Req: THorseRequest; Res: THorseResponse);
  end;

implementation

{ TPedidoController }

class procedure TPedidoController.RegistrarRotas;
begin
  THorse.Post('/pedidos', ReceberPedido);
  THorse.Get('/produtos', ListarProdutos);
  THorse.Post('/login', FazerLogin);
end;

class procedure TPedidoController.FazerLogin(Req: THorseRequest; Res: THorseResponse);
var
  JSONBody, JSONRetorno: TJSONObject;
  Usuario, SenhaDigitada, SenhaBanco: string;
  DBF: TConexaoDBF;
  Qry: TFDQuery;
begin
  JSONBody := Req.Body<TJSONObject>;
  Usuario := JSONBody.GetValue<string>('usuario').ToUpper;
  SenhaDigitada := JSONBody.GetValue<string>('senha');

  JSONRetorno := TJSONObject.Create;
  DBF := TConexaoDBF.Create;
  try
    // Aqui você faria o SELECT na tabela USUARIO
    // Lembre-se que o ADS precisa da senha de criptografia antes, se houver!
    Qry := DBF.AbrirTabela('USUARIO', 'NM_USUARIO, CD_SENHA', 'NM_USUARIO = ' + QuotedStr(Usuario), '');
    try
      if Qry.IsEmpty then
      begin
        JSONRetorno.AddPair('status', 'erro');
        JSONRetorno.AddPair('mensagem', 'Usuário não encontrado!');
        Res.Status(THTTPStatus.Unauthorized).Send(JSONRetorno);
      end
      else
      begin
        SenhaBanco := Qry.FieldByName('CD_SENHA').AsString.Trim;

        if SenhaDigitada = SenhaBanco then
        begin
          JSONRetorno.AddPair('status', 'ok');
          JSONRetorno.AddPair('mensagem', 'Login aprovado!');
          Res.Status(THTTPStatus.OK).Send(JSONRetorno);
        end
        else
        begin
          JSONRetorno.AddPair('status', 'erro');
          JSONRetorno.AddPair('mensagem', 'Senha incorreta!');
          Res.Status(THTTPStatus.Unauthorized).Send(JSONRetorno);
        end;
      end;
    finally
      Qry.Free;
    end;
  finally
    DBF.Free;
  end;
end;

class procedure TPedidoController.ListarProdutos(Req: THorseRequest; Res: THorseResponse);
var
  Repositorio: TPedidoRepository;
begin
  Repositorio := TPedidoRepository.Create;
  try
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
