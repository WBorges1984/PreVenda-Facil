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
  DBF: TConexaoDBF;
  Qry: TFDQuery;
  JSONRetorno: TJSONArray;
  JSONProduto: TJSONObject;
  TermoBusca, Condicao: string;
begin
  try
    // 1. Forma SEGURA de pegar o parâmetro. Se vier vazio, não dá erro 500!
    if not Req.Query.TryGetValue('busca', TermoBusca) then
      TermoBusca := '';

    JSONRetorno := TJSONArray.Create;
    DBF := TConexaoDBF.Create;
    try
      Condicao := '';
      if TermoBusca <> '' then
        Condicao := 'DS_PRODUTO LIKE ' + QuotedStr('%' + TermoBusca.ToUpper + '%');

      // 2. ATENÇÃO: Confirme se os campos abaixo existem com esses exatos nomes no seu DBF!
      Qry := DBF.AbrirTabela('"PRODUTO.dbf"', 'CD_PRODUTO, DS_PRODUTO, CD_UNIDADE, VL_PRODUTO', Condicao, 'DS_PRODUTO');
      try
        while not Qry.Eof do
        begin
          JSONProduto := TJSONObject.Create;
          JSONProduto.AddPair('codigo', Qry.FieldByName('CD_PRODUTO').AsString.Trim);
          JSONProduto.AddPair('descricao', Qry.FieldByName('DS_PRODUTO').AsString.Trim);
          JSONProduto.AddPair('unidade', Qry.FieldByName('CD_UNIDADE').AsString.Trim);
          JSONProduto.AddPair('preco', TJSONNumber.Create(Qry.FieldByName('VL_PRODUTO').AsFloat));

          JSONRetorno.AddElement(JSONProduto);
          Qry.Next;
        end;

        Res.Status(THTTPStatus.OK).Send(JSONRetorno);
      finally
        Qry.Free;
      end;
    finally
      DBF.Free;
    end;
  except
    on E: Exception do
    begin
      // 3. SE DER ERRO, DEVOLVE A MENSAGEM REAL PARA O APLICATIVO!
      Res.Status(THTTPStatus.InternalServerError).Send('Erro no banco de dados: ' + E.Message);
    end;
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
