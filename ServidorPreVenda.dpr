program ServidorPreVenda;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  uConexaoDBF in 'conexao/uConexaoDBF.pas',
  uPedidoRepository in 'Repository/uPedidoRepository.pas',
  uPedidoController in 'Controller/uPedidoController.pas';

begin
  try


    // 1. Habilita o suporte a JSON no Horse
    THorse.Use(Jhonson());

    // 2. Registra as rotas da nossa API (POO)
    TPedidoController.RegistrarRotas;

    // 3. Inicia o servidor
    THorse.Listen(9000,
      procedure
      begin
        Writeln('Servidor de Pre-Venda rodando na porta ' + THorse.Port.ToString);
        Writeln('Aguardando conexoes do App Android...');
      end);

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
