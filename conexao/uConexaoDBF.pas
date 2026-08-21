unit uConexaoDBF;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.ADS, FireDAC.Phys.ADSDef,
  FireDAC.Comp.Client, FireDAC.Stan.Param;

type
  TConexaoDBF = class
  private
    FConexao: TFDConnection;
    FDriverLink: TFDPhysADSDriverLink;
    FPasta: string;
    procedure Conectar;

  public
    // Se APasta n�o for informada, usa a pasta do execut�vel.
    constructor Create(const APasta: string = '');
    destructor Destroy; override;

    // Retorna um TFDQuery ABERTO com os dados da tabela informada.
    // O chamador � respons�vel por dar Free na query retornada.
    function AbrirTabela(const ANomeTabela: string;
      const ACampos: string = '*';
      const ACondicao: string = '';
      const AOrderBy: string = ''): TFDQuery;

    // NOVO: Executa um comando UPDATE genérico na tabela
    procedure AtualizarTabela(const ANomeTabela, ASets, ACondicao: string);

    // Atalho: preenche um TStrings (ex: ComboBox.Items) com os
    // valores de um �nico campo da tabela.
    procedure PreencherLista(const ANomeTabela, ACampo: string;
      AItens: TStrings; const AOrderBy: string = '');

    property Conexao: TFDConnection read FConexao;
  end;

    procedure CriarTabelasDelivery;

implementation

{ TConexaoDBF }

constructor TConexaoDBF.Create(const APasta: string);
begin
  inherited Create;

  if APasta <> '' then
    FPasta := APasta
  else
    FPasta := ExtractFilePath(ParamStr(0));

  if (FPasta <> '') and (FPasta[Length(FPasta)] <> PathDelim) then
    FPasta := FPasta + PathDelim;

  FDriverLink := TFDPhysADSDriverLink.Create(nil);
  FConexao := TFDConnection.Create(nil);

  Conectar;
end;

destructor TConexaoDBF.Destroy;
begin
  if Assigned(FConexao) then
    FConexao.Connected := False;

  FConexao.Free;
  FDriverLink.Free;

  inherited;
end;

procedure TConexaoDBF.AtualizarTabela(const ANomeTabela, ASets, ACondicao: string);
var
  LSQL: string;
begin
  // Monta a base do comando UPDATE
  LSQL := Format('UPDATE %s SET %s', [ANomeTabela, ASets]);

  // Se passou uma condição (WHERE), adiciona ao comando
  if ACondicao <> '' then
    LSQL := LSQL + ' WHERE ' + ACondicao;

  try
    // Executa a instrução diretamente no banco
    FConexao.ExecSQL(LSQL);
  except
    on E: Exception do
    begin
      raise Exception.CreateFmt('Erro ao atualizar a tabela "%s": %s',
        [ANomeTabela, E.Message]);
    end;
  end;
end;

procedure TConexaoDBF.Conectar;
begin
  FDriverLink.VendorLib := FPasta + 'ace32.dll';

  FConexao.Connected := False;
  FConexao.Params.Clear;
  FConexao.Params.Add('DriverID=ADS');
  FConexao.Params.Add('Database=' + FPasta);
  FConexao.Params.Add('ServerTypes=Local');
  FConexao.Params.Add('TableType=VFP');
  FConexao.Params.Add('ShowDeleted=False');
  FConexao.Params.Add('ReadOnly=false');
  FConexao.Params.Add('CharacterSet=ANSI');
  FConexao.Connected := True;
end;

function TConexaoDBF.AbrirTabela(const ANomeTabela, ACampos, ACondicao,
  AOrderBy: string): TFDQuery;
var
  LSQL: string;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConexao;

    LSQL := Format('SELECT %s FROM %s', [ACampos, ANomeTabela]);

    // NOVO: Se tiver uma condição, adiciona o WHERE
    if ACondicao <> '' then
      LSQL := LSQL + ' WHERE ' + ACondicao;

    if AOrderBy <> '' then
      LSQL := LSQL + ' ORDER BY ' + AOrderBy;

    Result.SQL.Text := LSQL;
    Result.Open;
  except
    on E: Exception do
    begin
      Result.Free;
      raise Exception.CreateFmt('Erro ao abrir a tabela "%s": %s',
        [ANomeTabela, E.Message]);
    end;
  end;
end;

procedure TConexaoDBF.PreencherLista(const ANomeTabela, ACampo: string;
  AItens: TStrings; const AOrderBy: string);
var
  qry: TFDQuery;
  LOrdem: string;
begin
  if AOrderBy <> '' then
    LOrdem := AOrderBy
  else
    LOrdem := ACampo;

  qry := AbrirTabela(ANomeTabela, ACampo, LOrdem);
  try
    AItens.Clear;
    qry.First;
    while not qry.Eof do
    begin
      AItens.Add(qry.FieldByName(ACampo).AsString);
      qry.Next;
    end;
  finally
    qry.Free;
  end;
end;

procedure CriarTabelasDelivery;
var
  DBF: TConexaoDBF;
  CaminhoPasta: string;
begin
  // Descobre a pasta onde o .exe está rodando
  CaminhoPasta := ExtractFilePath(ParamStr(0));

  DBF := TConexaoDBF.Create;
  try
    // 1. Só tenta criar a PEDDLV se o arquivo NÃO existir na pasta
    if not FileExists(CaminhoPasta + 'PEDDLV.DBF') then
    begin
      DBF.Conexao.ExecSQL(
        'CREATE TABLE PEDDLV (' +
        '  NR_PEDIDO CHAR(10), ' +
        '  DT_PEDIDO DATE, ' +
        '  HR_PEDIDO CHAR(5), ' +
        '  NR_CGC CHAR(14), ' +
        '  NM_CLIENTE CHAR(60), ' +
        '  NR_TEL CHAR(15), ' +
        '  DS_ENDEREC CHAR(60), ' +
        '  NR_ENDEREC CHAR(10), ' +
        '  DS_COMPL CHAR(30), ' +
        '  NM_BAIRRO CHAR(40), ' +
        '  CD_FORMPAG CHAR(3), ' +
        '  VL_TOTAL NUMERIC(15,2), ' +
        '  DS_STATUS CHAR(20)' +
        ')'
      );
      DBF.Conexao.ExecSQL('CREATE INDEX IDX_PEDIDO ON PEDDLV (NR_PEDIDO)');
      DBF.Conexao.ExecSQL('CREATE INDEX IDX_STATUS ON PEDDLV (DS_STATUS)');
    end;

    // 2. Só tenta criar a PEDDLVIT se o arquivo NÃO existir na pasta
    if not FileExists(CaminhoPasta + 'PEDDLVIT.DBF') then
    begin
      DBF.Conexao.ExecSQL(
        'CREATE TABLE PEDDLVIT (' +
        '  NR_PEDIDO CHAR(10), ' +
        '  NR_ITEM CHAR(3), ' +
        '  CD_PRODUTO CHAR(14), ' +
        '  DS_PRODUTO CHAR(60), ' +
        '  QT_PRODUTO NUMERIC(10,3), ' +
        '  VL_UNITARI NUMERIC(15,4), ' +
        '  VL_TOTAL NUMERIC(15,2), ' +
        '  DS_DETPROD MEMO' +
        ')'
      );
      DBF.Conexao.ExecSQL('CREATE INDEX IDX_ITENS ON PEDDLVIT (NR_PEDIDO)');
    end;

  finally
    DBF.Free;
  end;
end;

end.
