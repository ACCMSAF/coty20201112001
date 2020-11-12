CREATE OR REPLACE PACKAGE GSR_COTY_PIS_COF_AJU_MAN_CPROC IS

  -- autor   : Everton Zamarioli
  -- created : 12/08/2014
  -- purpose : Ajustes Manuais PIS/COFINS

  /* VARIÁVEIS DE CONTROLE DE CABEÇALHO DE RELATÓRIO */
    FUNCTION Parametros RETURN VARCHAR2;
    FUNCTION Nome RETURN VARCHAR2;
    FUNCTION Tipo RETURN VARCHAR2;
    FUNCTION Versao RETURN VARCHAR2;
    FUNCTION Descricao RETURN VARCHAR2;
    FUNCTION Modulo RETURN VARCHAR2;
    FUNCTION Classificacao RETURN VARCHAR2;

-- declaração de types
  type tCodEstab              is table of varchar2(6) index by binary_integer;
  geracaoCentralizada      boolean;

procedure insere_log(vs_log  varchar2
                   , vn_nivel number
                   , mproc_id number) ;

    FUNCTION Executar (p_data_ref           date
                 , p_perfil             number
                -- , vs_ger_registros     varchar2
                 --, p_proc_estab_emp     varchar2
                 , p_cod_emp_estab      varchar2
                 )RETURN INTEGER;

Procedure insert_table_M220_M620 (p_cod_empresa    in varchar2,
                                    p_cod_estab      in varchar2,
                                    p_cod_tipo_livro in varchar2,
                                    p_dat_apur_ini   in date,
                                    p_dat_apur_fim   in date,
                                    p_cod_reg_m210_m610 in varchar2,
                                    p_cod_cont       in varchar2,
                                    p_aliq           in number,
                                    p_aliq_quant     in number,
                                    p_cod_reg        in varchar2,
                                    p_ind_aj         in varchar2,
                                    p_vl_aj          in number,
                                    p_cod_aj         in varchar2,
                                    p_num_doc        in varchar2,
                                    p_dsc_aj         in varchar2,
                                    p_dt_ref         in date,
                                    p_texto          in varchar2,
                                    pmensagem       out varchar2,
                                    pstatus         out varchar2);

Procedure insert_table_M110_M510 (p_cod_empresa    in varchar2,
                                    p_cod_estab      in varchar2,
                                    p_cod_tipo_livro in varchar2,
                                    p_dat_apur_ini   in date,
                                    p_dat_apur_fim   in date,
                                    p_cod_reg_m100_m500 in varchar2,
                                    p_cod_cred       in varchar2,
                                    p_ind_cred_ori   in varchar2,
                                    p_aliq           in number,
                                    p_aliq_quant     in number,
                                    p_cod_reg        in varchar2,
                                    p_ind_aj         in varchar2,
                                    p_cod_aj         in varchar2,
                                    p_dt_ref         in date,
                                    p_vl_aj          in number,
                                    p_num_doc        in varchar2,
                                    p_dsc_aj         in varchar2,
                                    p_ind_gravacao   in varchar2,
                                    p_texto          in varchar2,
                                    pmensagem       out varchar2,
                                    pstatus         out varchar2,
                                    in_rest_m110_m510_w out number);

Function FormataValor_pc (Valor        In Varchar2,
                       vs_tipo          varchar2,      -- Tipo do Campo (Caracter, Numérico, Data, Texto Fixo etc)
                       vn_decimais      Integer,       -- Número de Casas Decimais
                       vn_tamanho       Integer,       -- Tamanho do Campo
                       vn_tamnhoMsaf    Integer,       -- Tamanho do campo no Mastersaf, usado p/ montagem da chave
                       IndCHave      In varchar2 Default 'N') Return Varchar2 ;



procedure processa_dados_M110_M510(vs_cod_empresa         varchar2
                                 , p_cod_emp_estab      varchar2
                                 , vd_data_ini            date
                                 , vd_data_fim            date
                                 , p_perfil               number);

END GSR_COTY_PIS_COF_AJU_MAN_CPROC;
/
CREATE OR REPLACE PACKAGE body GSR_COTY_PIS_COF_AJU_MAN_CPROC IS

  mcod_empresa empresa.cod_empresa%TYPE;
  musuario     usuario_estab.cod_usuario%TYPE;
  vs_back_color_dados_rel varchar2(200);

dadosEstabCentr          estabelecimento%rowtype;
dadosEstab               estabelecimento%rowtype;
dadosEmpresa             empresa%rowtype;
uf_Estab                 estado.cod_estado%type;
plog                     varchar2(4000);
mproc_id                 integer;
mLinha                   Varchar2(2000);
vn_id_reg_apur           number;
vn_by                    integer := 1;

procedure setEstabGeracao (pCodEmpresa in varchar2
                         , pCodEstab in varchar2
                         ) is

  begin
    begin
      select *
        into dadosEstab
        from estabelecimento
       where cod_empresa = pCodEmpresa
         and cod_estab   = pCodEstab;

      if dadosEstab.Ident_Estado is not null then
        select cod_estado
          into uf_Estab
          from estado
         where ident_estado = dadosEstab.Ident_Estado;
      end if;
    exception
      when others then
        lib_proc.add_log('Empresa/Estabelecimento Problemas ao acessar dados do estabelecimento.',1);
        return;
    end;



  end setEstabGeracao;


procedure setEstabCentr (pCodEmpresa in varchar2, pCodEstab in varchar2) is
    --nomeProc constant varchar2(30) := '.setEstabCentr';
    --status   integer;
  begin

    begin
      select *
        into dadosEmpresa
        from empresa
       where cod_empresa = pCodEmpresa;
    exception
      when others then
       -- pkg_log.setOrigem(nomePkg || nomeProc);
        lib_proc.add_log('Empresa/Estabelecimento, Problemas ao acessar dados da empresa.',1);
        return;
    end;

    begin
      select *
        into dadosEstabCentr
        from estabelecimento
       where cod_empresa = pCodEmpresa
         and cod_estab   = pCodEstab;
    exception
      when others then
        --pkg_log.setMensagemBanco(sqlerrm);
        --pkg_log.setOrigem(nomePkg || nomeProc);
        lib_proc.add_log('Empresa/Estabelecimento, Problemas ao acessar dados do estabelecimento centralizador.',1);
        return;
    end;


  end setEstabCentr;

function getEstabCentr return estabelecimento%rowtype is
  begin
    return dadosEstabCentr;
  end getEstabCentr;

PROCEDURE MONTA_LINHA (PS_LINHA IN VARCHAR2, vn_rel number) IS

  BEGIN

  LIB_PROC.ADD (PLINHA => REPLACE(PS_LINHA,CHR(10),''),PTIPO =>vn_rel);

END MONTA_LINHA;

procedure cabecalho(ps_nome_rel            varchar2
                   ,vn_rel                 number
                   ,vs_razao_social_matriz varchar2
                   ,vs_cnpj_matriz         varchar2
                   ,vn_num_processo        number
                   ,vd_data_ini            date
                   ,vd_data_fim            date
                   ,vs_nome_interface      varchar2
                   )  is

vs_color_background varchar2(200);

  begin

   vs_color_background := 'background-color: rgb(255, 242, 191);';


    MONTA_LINHA('<html>',vn_rel);
    MONTA_LINHA('<head>',vn_rel);
    MONTA_LINHA('<meta content="text/html; charset=ISO-8859-1"',vn_rel);
    MONTA_LINHA('http-equiv="content-type">',vn_rel);
    MONTA_LINHA('<title>Impostos</title>',vn_rel);
    MONTA_LINHA('</head>',vn_rel);
    MONTA_LINHA('<body>',vn_rel);
    MONTA_LINHA('<span style="text-decoration: underline;"></span>',vn_rel);
    MONTA_LINHA('<table style="border: 1px solid black; text-align: left; width: 100%;"',vn_rel);
    MONTA_LINHA('border="1" cellpadding="2" cellspacing="2">',vn_rel);
    MONTA_LINHA('<tbody>',vn_rel);

    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('</tr>',vn_rel);




    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('<tr style="font-weight: bold;" align="center">',vn_rel);
    MONTA_LINHA('<td colspan="18" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; ">',vn_rel);
    MONTA_LINHA('<big><big>'||ps_nome_rel||'</big></big> </td>',vn_rel);






    MONTA_LINHA('</tr>',vn_rel);

    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('<td colspan="18" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; "><br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);
    MONTA_LINHA('</tr>',vn_rel);

    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('<tr align="center">',vn_rel);
    MONTA_LINHA('<td colspan="18" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; "><big><big><span',vn_rel);
    MONTA_LINHA('style="font-weight: bold;">'||vs_nome_interface||'</span></big></big><br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);
    MONTA_LINHA('</tr>',vn_rel);

    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('<td colspan="9" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; font-weight: bold; font-size: 16px;">Empresa:'||vs_cnpj_matriz||' - '||vs_razao_social_matriz||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);
    MONTA_LINHA('<td colspan="5" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; font-weight: bold; font-size: 16px;white-space: nowrap; ">Data',vn_rel);
    MONTA_LINHA('Ini Processamento: '||TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS')||'</td>',vn_rel);
    MONTA_LINHA('<td colspan="2" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; font-weight: bold; font-size: 16px;white-space: nowrap;">Data Inicio:'||vd_data_ini||'</td>',vn_rel);
    MONTA_LINHA('<td colspan="2" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; font-weight: bold;font-size: 16px; white-space: nowrap;">Data Fim:'||vd_data_fim||'</td',vn_rel);
    MONTA_LINHA('</tr>',vn_rel);


    MONTA_LINHA('<tr>',vn_rel);
    MONTA_LINHA('<td colspan="18" rowspan="1"',vn_rel);
    MONTA_LINHA('style="vertical-align: top; font-weight: bold; font-size: 16px;white-space: nowrap;">Processo:'||vn_num_processo||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);
    MONTA_LINHA('</tr>',vn_rel);

    MONTA_LINHA('<tr>',vn_rel);


    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' font-weight: bold; text-align: center; white-space: nowrap;">Empresa<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' font-weight: bold; text-align: center;white-space: nowrap;">Estab.<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' font-weight: bold; text-align: center;white-space: nowrap;">Tipo de livro Apuracao<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Data Inicio<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Data Fim<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Codigo do registro pai M100, M500<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Codigo do tipo de credito do registro pai M100, M500<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Indicador de origem do credito do registro pai M100, M500<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Alíquota do Pis/Cofins do registro pai M100, M500<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Alíquota em reais do Pis/Cofins do registro pai M100, M500<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Codigo dos registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Tipo de ajuste dos Registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Codig de ajuste dos Registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Data referencia dos registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Valor do ajuste dos registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Numero do documento/processo dos registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Descricao resumida dos registros M110, M510<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td',vn_rel);
    MONTA_LINHA('style="vertical-align: top; '||vs_color_background||' text-align: center;white-space: nowrap;font-weight: bold;">Texto<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('</tr>',vn_rel);





  end;

procedure dados_relatorio ( p_cod_empresa    in varchar2,
                            p_cod_estab      in varchar2,
                            p_cod_tipo_livro in varchar2,
                            p_dat_apur_ini   in date,
                            p_dat_apur_fim   in date,
                            p_cod_reg_m100_m500 in varchar2,
                            p_cod_cred       in varchar2,
                            p_ind_cred_ori   in varchar2,
                            p_aliq           in number,
                            p_aliq_quant     in number,
                            p_cod_reg        in varchar2,
                            p_ind_aj         in varchar2,
                            p_cod_aj         in varchar2,
                            p_dt_ref         in date,
                            p_vl_aj          in number,
                            p_num_doc        in varchar2,
                            p_dsc_aj         in varchar2,
                            p_texto          in varchar2,
                            vn_rel           number) is






begin

    if vs_back_color_dados_rel is null or vs_back_color_dados_rel = 'background-color: rgb(230, 230, 230);' then

       vs_back_color_dados_rel := 'background-color: white;';
    else

      vs_back_color_dados_rel := 'background-color: rgb(230, 230, 230);';
    end if;

    MONTA_LINHA('<tr>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_COD_EMPRESA||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_COD_ESTAB||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_cod_tipo_livro||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_dat_apur_ini||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_dat_apur_fim||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_cod_reg_m100_m500||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_cod_cred||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_ind_cred_ori||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_aliq||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_aliq_quant||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: left; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_cod_reg||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: left; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_ind_aj||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);


    MONTA_LINHA('<td style="vertical-align: top; text-align: right; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_cod_aj||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_dt_ref||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_vl_aj||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_num_doc||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_dsc_aj||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('<td style="vertical-align: top; text-align: center; font-weight: bold; font-size: 16px;white-space: nowrap;'||vs_back_color_dados_rel||'">'||p_texto||'<br>',vn_rel);
    MONTA_LINHA('</td>',vn_rel);

    MONTA_LINHA('</tr>',vn_rel);

end;

procedure final_html(vn_rel number) is

  begin

    MONTA_LINHA('</tbody>',vn_rel);
    MONTA_LINHA('</table>',vn_rel);
    MONTA_LINHA('<br>',vn_rel);
--    MONTA_LINHA('<span style="text-decoration: underline;"></span><br>',vn_rel);
    MONTA_LINHA('</body>',vn_rel);
    MONTA_LINHA('</html>',vn_rel);

end;

procedure setIndGeracaoCentralizada (param in boolean) is
  begin
    geracaoCentralizada := param;
  end setIndGeracaoCentralizada;

function getListaEstabs return tCodEstab is

    lista tCodEstab;

  begin

    setIndGeracaoCentralizada(false);

    for c_estab in
      (select central.cod_estab, 'C' tipo
         from central_escrit_contabil central
        where central.cod_empresa = dadosEstabCentr.Cod_Empresa
          and central.cod_estab_central = dadosEstabCentr.Cod_Estab
       union all
       select dadosEstabCentr.Cod_Estab, 'D' tipo
         from dual
			  where not exists (select 1
         from central_escrit_contabil central
        where central.cod_empresa = dadosEstabCentr.Cod_Empresa
          and central.cod_estab_central = dadosEstabCentr.Cod_Estab))
    loop
      lista(lista.count + 1) := c_estab.cod_estab;
      -- Neste ponto iremos determinar se a geração será centralizada
      -- ou descentralizada
      if c_estab.tipo = 'C' then
        setIndGeracaoCentralizada(true);
      end if;
    end loop;

    return lista;

  end getListaEstabs;

procedure processa_dados_M110_M510(vs_cod_empresa         varchar2
                                 , p_cod_emp_estab      varchar2
                                 , vd_data_ini            date
                                 , vd_data_fim            date
                                 , p_perfil               number) is



listaEstabs      GSR_COTY_PIS_COF_AJU_MAN_CPROC.tCodEstab;

l_crlf                   varchar2(2) := chr(13) || chr(10);

c_limit                  PLS_INTEGER := 1000;
idx_w                    integer;
vSQL_Stmt                long;
cSQL_Cur                 INTEGER;
cur_var                  SYS_REFCURSOR;
cRetVal                  INTEGER;
vs_ignora_reg            exception;

 TYPE r_dados IS RECORD
   (cod_empresa            dwt_docto_fiscal.cod_empresa%type
, cod_estab                dwt_docto_fiscal.cod_estab%type
, data_fiscal              dwt_docto_fiscal.data_fiscal%type
, movto_e_s                dwt_docto_fiscal.movto_e_s%type
, norm_dev                 dwt_docto_fiscal.norm_dev%type
, num_docfis               dwt_docto_fiscal.num_docfis%type
, serie_docfis             dwt_docto_fiscal.serie_docfis%type
, cod_cfo                  x2012_cod_fiscal.cod_cfo%type
, cod_natureza_op          x2006_natureza_op.cod_natureza_op%type
, cod_situacao_pis         dwt_itens_merc.cod_situacao_pis%type
, cod_situacao_cofins      dwt_itens_merc.cod_situacao_cofins%type
, vlr_aliq_pis             dwt_itens_merc.vlr_aliq_pis%type
, vlr_base_pis             dwt_itens_merc.vlr_base_pis%type
, vlr_pis                  dwt_itens_merc.vlr_pis%type
, vlr_aliq_cofins          dwt_itens_merc.vlr_aliq_cofins%type
, vlr_base_cofins          dwt_itens_merc.vlr_base_cofins%type
, vlr_cofins               dwt_itens_merc.vlr_cofins%type
, descr_nat                x2006_natureza_op.descricao%type

  );


TYPE t_dados IS TABLE OF r_dados INDEX BY BINARY_INTEGER;
l_reg   t_dados;

vs_cod_tipo_livro    varchar2(100);
vs_cod_cred          varchar2(10);
vs_tipo_aju          varchar2(2);
vs_valor_campo       varchar2(17);
pMensagem            varchar2(4000);
pStatus              varchar2(3);
vn_valor_ajuste      number(17,2):=0;
vn_aliq_pis_quant    number(19,4);
vs_cod_reg_m100_m500 varchar2(5);
vn_aliq_pis_cofins   number(8,4):= 0;
vs_cod_reg           varchar2(5);
vs_texto             varchar2(4000);
vs_num_doc           varchar2(200);
vs_bloco_m           varchar2(10);
vs_descr_aju         varchar2(200);
vs_cod_aju           varchar2(2);
vn_in_rest_m110_m510_w number;

i_estab           integer;
vs_ind_cred_ori   varchar2(2);

  begin


begin


   setEstabCentr(vs_cod_empresa, p_cod_emp_estab);
   setEstabGeracao (vs_cod_empresa, p_cod_emp_estab);
-- A função getListaEstabs retorna todos os estabelecimentos centralizados
   listaEstabs      := getListaEstabs;

          -- processa os estabelecimentos parametrizados
          i_estab := listaEstabs.first;




           for mreg in (select rowid
                          from EPC_REST_AJT_M110_M510
                         where dat_apur_ini  = to_date(vd_data_ini,'dd/mm/yyyy')
                         and dat_apur_fim = to_date(vd_data_fim,'dd/mm/yyyy')
                         and cod_empresa = mcod_empresa
                         and cod_estab = p_cod_emp_estab) loop

             delete EPC_REST_AJT_M110_M510 where rowid = mreg.rowid;
           --  commit;

           end loop;
           commit;

          while i_estab is not null loop







             -- roda para todos os parametros

             for reg in (select  distinct trim(det1.nome_param) nome_param
                           from  fpar_param_det   det1,
                                 fpar_parametros  par
                           where par.nome_framework     = 'GSR_COTY_AJUSTE_APUR_CPAR'
                             and par.id_parametros      = p_perfil
                             and par.id_parametros = det1.id_parametro
                             and det1.nome_param like 'NAT_BC_COTY%' ) loop

                      vSQL_Stmt := ' SELECT X08.COD_EMPRESA,'||l_crlf||
                      ' X08.COD_ESTAB,'||l_crlf||
                      ' X08.DATA_FISCAL,'||l_crlf||
                      ' X08.MOVTO_E_S,'||l_crlf||
                      ' X08.NORM_DEV,'||l_crlf||
                      ' X08.NUM_DOCFIS,'||l_crlf||
                      ' X08.SERIE_DOCFIS,'||l_crlf||
                      ' CFOP.COD_CFO,'||l_crlf||
                      ' NATOP.COD_NATUREZA_OP,'||l_crlf||
                      ' X08.COD_SITUACAO_PIS,'||l_crlf||
                      ' X08.COD_SITUACAO_COFINS,'||l_crlf||
                      ' X08.VLR_ALIQ_PIS,'||l_crlf||
                      ' SUM(X08.VLR_BASE_PIS) VLR_BASE_PIS,'||l_crlf||
                      ' SUM(X08.VLR_PIS) VLR_PIS,'||l_crlf||
                      ' X08.VLR_ALIQ_COFINS,'||l_crlf||
                      ' SUM(X08.VLR_BASE_COFINS) VLR_BASE_COFINS,'||l_crlf||
                      ' SUM(X08.VLR_COFINS) VLR_COFINS, '||l_crlf||
                      ' MAX(det1.valor) DESCR_NAT '||l_crlf||
                ' FROM DWT_ITENS_MERC    X08,'||l_crlf||
                      ' DWT_DOCTO_FISCAL  x07, '||l_crlf||
                      ' X2006_NATUREZA_OP NATOP,'||l_crlf||
                      ' X2012_COD_FISCAL  CFOP, '||l_crlf||
                      ' fpar_param_det   det1, '||l_crlf||
                      ' fpar_param_estab est,'||l_crlf||
                      ' fpar_parametros  par'||l_crlf||
               ' WHERE X08.IDENT_NATUREZA_OP = NATOP.IDENT_NATUREZA_OP'||l_crlf||
               ' AND X08.IDENT_CFO         = CFOP.IDENT_CFO'||l_crlf||
               ' AND x07.DATA_FISCAL between to_date('''||vd_data_ini||''',''dd/mm/yyyy'')  and to_date('''||vd_data_fim||''',''dd/mm/yyyy'')  '||l_crlf||
               ' AND  ((X08.COD_SITUACAO_PIS    IN (''49'', ''98'')) '||l_crlf||
                  ' OR (X08.COD_SITUACAO_COFINS IN (''49'', ''98''))) '||l_crlf||
               ' AND    x07.COD_ESTAB         = '||''''||listaEstabs(i_estab)||''''||l_crlf||
               ' AND  ((X08.VLR_ALIQ_PIS > 0 AND X08.VLR_BASE_PIS > 0 AND X08.VLR_PIS > 0) '||l_crlf||
               ' OR (X08.VLR_ALIQ_COFINS > 0 AND X08.VLR_BASE_COFINS > 0 AND X08.VLR_COFINS > 0)) '||l_crlf||
                 ' and est.id_parametros      = det1.id_parametro '||l_crlf||
                 ' and est.id_parametros      = par.id_parametros '||l_crlf||
                 ' and est.cod_estab          = x07.cod_estab '||l_crlf||
                 ' and par.id_parametros      = est.id_parametros '||l_crlf||
                 ' and x07.ident_docto_fiscal = x08.ident_docto_fiscal '||l_crlf||
                 ' AND ((SITUACAO <> ''S'') OR (IND_NFE_DENEG_INUT NOT IN (1, 2)))'||l_crlf||
                 ' and par.nome_framework     = ''GSR_COTY_AJUSTE_APUR_CPAR'' '||l_crlf||
                 ' and par.id_parametros      = '||''''||p_perfil||''''||l_crlf||
                 ' and trim(det1.nome_param)  = '||''''||reg.nome_param||''''||l_crlf||
                 ' and est.cod_empresa        = '||''''||vs_cod_empresa||''''||l_crlf||
                 ' and det1.conteudo          = CFOP.COD_CFO||'' - ''|| NATOP.COD_NATUREZA_OP '||l_crlf||
                 ' and est.cod_empresa        = x07.cod_empresa '||l_crlf||
                 ' GROUP BY X08.COD_EMPRESA,'||l_crlf||
                        ' X08.COD_ESTAB,'||l_crlf||
                        ' X08.DATA_FISCAL,'||l_crlf||
                        ' X08.MOVTO_E_S,'||l_crlf||
                        ' X08.NORM_DEV,'||l_crlf||
                        ' X08.NUM_DOCFIS,'||l_crlf||
                        ' X08.SERIE_DOCFIS,'||l_crlf||
                        ' CFOP.COD_CFO,'||l_crlf||
                        ' NATOP.COD_NATUREZA_OP,'||l_crlf||
                        ' X08.COD_SITUACAO_PIS,'||l_crlf||
                        ' X08.COD_SITUACAO_COFINS,'||l_crlf||
                        ' X08.VLR_ALIQ_PIS, '||l_crlf||
                        ' X08.VLR_ALIQ_COFINS ';

         -- execute immediate 'truncate table gsr_debug';
         -- insert into gsr_debug(texto)values (vSQL_Stmt);
         -- commit;

             begin
                cSQL_Cur := dbms_sql.open_cursor;
                dbms_sql.parse(cSQL_Cur, vSQL_Stmt, dbms_sql.NATIVE);
                cRetVal := dbms_sql.execute(cSQL_Cur);
                cur_var := dbms_sql.to_refcursor(cSQL_Cur);

                FETCH cur_var
                BULK COLLECT INTO l_reg
                LIMIT c_limit;

                idx_w := l_reg.first;

             exception when no_data_found then
               vn_by := 1; -- null;
               when others then
               lib_proc.add_log('Erro ao processar cursor Gera Servicos, principal '||sqlerrm,1);
             end;

             while idx_w is not null loop


                    vs_cod_tipo_livro := 'EPC';



                    vs_ind_cred_ori   := '0';

                    vs_cod_aju := '05';--,'05 - Ajuste Oriundo de Outras Situacoes', '06 - Estorno'

                    IF l_reg(idx_w).MOVTO_E_S <> '9' THEN
                       vs_tipo_aju       := '1';  --0 - Ajuste de Reducao 1 - Ajuste Acrescimo
                    ELSE
                       vs_tipo_aju       := '0';  --0 - Ajuste de Reducao 1 - Ajuste Acrescimo
                    END IF ;




                    if nvl(l_reg(idx_w).VLR_PIS,0) > 0  then


                       if nvl(l_reg(idx_w).VLR_ALIQ_PIS,0) = '1.65' then
                          vs_cod_cred       := '101';
                       elsif nvl(l_reg(idx_w).VLR_ALIQ_PIS,0) = '2.20' then
                          vs_cod_cred       := '202';
                       elsif nvl(l_reg(idx_w).VLR_ALIQ_PIS,0) in ('2.10','3.52') then
                          vs_cod_cred       := '108';
                       end if;

                       vs_cod_reg_m100_m500 := '100';
                       vn_aliq_pis_cofins   := l_reg(idx_w).VLR_ALIQ_PIS; --'1.65';
                       vs_num_doc := substr('Aliquota: '||vn_aliq_pis_cofins||'% e CFOP '||l_reg(idx_w).COD_CFO||'/'||l_reg(idx_w).COD_NATUREZA_OP||' - '||l_reg(idx_w).DESCR_NAT,1,150);
                       vs_descr_aju := 'REFERENTE NF '||l_reg(idx_w).NUM_DOCFIS;

                       vs_cod_reg           := '110';
                       vs_bloco_m           := 'M110';
                       vn_valor_ajuste := l_reg(idx_w).VLR_PIS;

                       vs_valor_campo := trim(REPLACE(REPLACE(REPLACE(TO_CHAR(to_number(vn_valor_ajuste),'99999999999999.99'),'.',';'),',','.'),';',','));
                       vs_valor_campo := FormataValor_pc(vs_valor_campo,'N',2,17,17,'N');
                       vs_texto := '|'||vs_bloco_m||'|'||vs_tipo_aju||'|'||vs_valor_campo||'|'||vs_cod_aju||'|'||vs_num_doc||'|'||vs_descr_aju||'|'||to_char(vd_data_fim,'ddmmyyyy')||'|';

                       Begin
                         --lib_proc.add_log('Inserindo dados insert_table_M110_M510',1);

                          insert_table_M110_M510(mcod_empresa
                                          , p_cod_emp_estab --listaEstabs(i_estab)
                                          , vs_cod_tipo_livro
                                          , vd_data_ini
                                          , vd_data_fim
                                          , vs_cod_reg_m100_m500
                                          , vs_cod_cred
                                          , vs_ind_cred_ori
                                          , vn_aliq_pis_cofins
                                          , vn_aliq_pis_quant --aliq_pis_quant ,
                                          , vs_cod_reg
                                          , vs_tipo_aju
                                          , vs_cod_aju
                                          , vd_data_fim
                                          , vn_valor_ajuste
                                          , vs_num_doc --i.num_doc  ,
                                          , vs_descr_aju
                                          , '4'
                                          , vs_texto
                                          , pMensagem
                                          , pStatus
                                          , vn_in_rest_m110_m510_w
                                          );

                                          --commit;
                          if pstatus = -1 then
                             lib_proc.add_log('Erro ao inserir dados',1);
                            exit;
                          end if;
                       exception
                        when others then
                           pStatus   := -1;
                           pMensagem := substr(sqlerrm,1,100);
                          lib_proc.add_log('Erro ao inserir dados',1);
                       end;


--- dados relatorio
                       dados_relatorio(mcod_empresa
                                          , p_cod_emp_estab --listaEstabs(i_estab)
                                          , vs_cod_tipo_livro
                                          , vd_data_ini
                                          , vd_data_fim
                                          , vs_cod_reg_m100_m500
                                          , vs_cod_cred
                                          , vs_ind_cred_ori
                                          , vn_aliq_pis_cofins
                                          , vn_aliq_pis_quant --aliq_pis_quant ,
                                          , vs_cod_reg
                                          , vs_tipo_aju
                                          , vs_cod_aju
                                          , vd_data_fim
                                          , vn_valor_ajuste
                                          , vs_num_doc --i.num_doc  ,
                                          , vs_descr_aju
                                          , vs_texto
                                          , 1);


                         -- imprime arquivo
                         mLinha := vn_id_reg_apur
                          || ';' ||vn_in_rest_m110_m510_w
                          || ';' ||vs_cod_reg
                          || ';' ||vs_tipo_aju
                          || ';' ||'05'
                          || ';' ||TO_CHAR(l_reg(idx_w).DATA_FISCAL,'DD/MM/YYYY')
                          || ';' ||TO_CHAR(vn_valor_ajuste)
                          || ';' ||VS_NUM_DOC
                          || ';' ||'REFERENTE NF '||l_reg(idx_w).NUM_DOCFIS
                          || ';' ||'4';

                          lib_proc.add(mLinha, null, null, 2);




                    end if;

                    if nvl(l_reg(idx_w).VLR_COFINS,0) > 0  then

                      if nvl(l_reg(idx_w).VLR_ALIQ_COFINS,0) = '7.60' then
                          vs_cod_cred       := '101';
                       elsif nvl(l_reg(idx_w).VLR_ALIQ_COFINS,0) = '10.30' then
                          vs_cod_cred       := '202';
                       elsif nvl(l_reg(idx_w).VLR_ALIQ_COFINS,0) in ('9.65','16.48') then
                          vs_cod_cred       := '108';
                       end if;

                      vs_cod_reg_m100_m500 := '500';
                      vn_aliq_pis_cofins   := l_reg(idx_w).VLR_ALIQ_COFINS;--'7.60';
                      vs_num_doc := substr('Aliquota: '||vn_aliq_pis_cofins||'% e CFOP '||l_reg(idx_w).COD_CFO||'/'||l_reg(idx_w).COD_NATUREZA_OP||' - '||l_reg(idx_w).DESCR_NAT,1,150);
                      vs_descr_aju := 'REFERENTE NF '||l_reg(idx_w).NUM_DOCFIS;

                      vs_cod_reg           := '510';
                      vs_bloco_m           := 'M510';
                      vn_valor_ajuste := l_reg(idx_w).VLR_COFINS;

                      vs_valor_campo := trim(REPLACE(REPLACE(REPLACE(TO_CHAR(to_number(vn_valor_ajuste),'99999999999999.99'),'.',';'),',','.'),';',','));
                      vs_valor_campo := FormataValor_pc(vs_valor_campo,'N',2,17,17,'N');
                      vs_texto := '|'||vs_bloco_m||'|'||vs_tipo_aju||'|'||vs_valor_campo||'|'||vs_cod_aju||'|'||vs_num_doc||'|'||vs_descr_aju||'|'||to_char(vd_data_fim,'ddmmyyyy')||'|';

                      Begin

                          insert_table_M110_M510(mcod_empresa
                                          , p_cod_emp_estab --listaEstabs(i_estab)
                                          , vs_cod_tipo_livro
                                          , vd_data_ini
                                          , vd_data_fim
                                          , vs_cod_reg_m100_m500
                                          , vs_cod_cred
                                          , vs_ind_cred_ori
                                          , vn_aliq_pis_cofins
                                          , vn_aliq_pis_quant --aliq_pis_quant ,
                                          , vs_cod_reg
                                          , vs_tipo_aju
                                          , vs_cod_aju
                                          , vd_data_fim
                                          , vn_valor_ajuste
                                          , vs_num_doc --i.num_doc  ,
                                          , vs_descr_aju
                                          , '4'
                                          , vs_texto
                                          , pMensagem
                                          , pStatus
                                          , vn_in_rest_m110_m510_w
                                          );

                                          --commit;

                          if pstatus = -1 then
                             lib_proc.add_log('Erro ao inserir dados',1);
                            exit;
                          end if;
                       exception
                        when others then
                           pStatus   := -1;
                           pMensagem := substr(sqlerrm,1,100);
                          lib_proc.add_log('Erro ao inserir dados',1);
                       end;


                       --- dados relatorio
                       dados_relatorio(mcod_empresa
                                          , p_cod_emp_estab --listaEstabs(i_estab)
                                          , vs_cod_tipo_livro
                                          , vd_data_ini
                                          , vd_data_fim
                                          , vs_cod_reg_m100_m500
                                          , vs_cod_cred
                                          , vs_ind_cred_ori
                                          , vn_aliq_pis_cofins
                                          , vn_aliq_pis_quant --aliq_pis_quant ,
                                          , vs_cod_reg
                                          , vs_tipo_aju
                                          , vs_cod_aju
                                          , vd_data_fim
                                          , vn_valor_ajuste
                                          , vs_num_doc --i.num_doc  ,
                                          , vs_descr_aju
                                          , vs_texto
                                          , 1);


                         -- imprime arquivo
                         mLinha := vn_id_reg_apur
                          || ';' ||vn_in_rest_m110_m510_w
                          || ';' ||vs_cod_reg
                          || ';' ||vs_tipo_aju
                          || ';' ||'05'
                          || ';' ||TO_CHAR(l_reg(idx_w).DATA_FISCAL,'DD/MM/YYYY')
                          || ';' ||TO_CHAR(vn_valor_ajuste)
                          || ';' ||VS_NUM_DOC
                          || ';' ||'REFERENTE NF '||l_reg(idx_w).NUM_DOCFIS
                          || ';' ||'4';

                          lib_proc.add(mLinha, null, null, 2);

                    end if;



                    idx_w := l_reg.next(idx_w);

                    IF idx_w IS NULL THEN
                      FETCH cur_var
                      BULK COLLECT INTO l_reg
                      LIMIT c_limit;

                        idx_w := l_reg.first;
                    END IF;


                end loop;
                --commit;

                IF cur_var%ISOPEN = TRUE THEN
                     CLOSE cur_var;
                     l_reg.delete;
                END IF;


            end loop;
            -- próximo estabelecimento
            i_estab := listaEstabs.next(i_estab);

          end loop;
          commit; 
          
  exception when others then
       lib_proc.add_log(sqlerrm,1);
  end;






exception when others then
 lib_proc.add_log('Erro ao processar dados '||sqlerrm,1);
end;

Procedure insert_table_M110_M510 (p_cod_empresa    in varchar2,
                                    p_cod_estab      in varchar2,
                                    p_cod_tipo_livro in varchar2,
                                    p_dat_apur_ini   in date,
                                    p_dat_apur_fim   in date,
                                    p_cod_reg_m100_m500 in varchar2,
                                    p_cod_cred       in varchar2,
                                    p_ind_cred_ori   in varchar2,
                                    p_aliq           in number,
                                    p_aliq_quant     in number,
                                    p_cod_reg        in varchar2,
                                    p_ind_aj         in varchar2,
                                    p_cod_aj         in varchar2,
                                    p_dt_ref         in date,
                                    p_vl_aj          in number,
                                    p_num_doc        in varchar2,
                                    p_dsc_aj         in varchar2,
                                    p_ind_gravacao   in varchar2,
                                    p_texto          in varchar2,
                                    pmensagem       out varchar2,
                                    pstatus         out varchar2,
                                    in_rest_m110_m510_w out number)  is

    linha_w number;
  -- in_rest_m110_m510_w number;
    nomeProc constant varchar2(40) := '.insert_table_m110_m510';
    nomePkg  varchar2(200) := 'GSR_COTY_PIS_COF_AJU_MAN_CPROC';
    Begin
      pStatus := 0;
      Begin
        select count(*)
        into linha_w
        from EPC_REST_AJT_M110_M510
        where cod_empresa     = p_cod_empresa and
              cod_estab       = p_cod_estab and
              cod_tipo_livro  = p_cod_tipo_livro and
              dat_apur_ini    = p_dat_apur_ini and
              dat_apur_fim    = p_dat_apur_fim and
              nvl(cod_reg_m100_m500, ' ')      = nvl(p_cod_reg_m100_m500, ' ') and
              nvl(cod_cred_m100_m500, ' ')     = nvl(p_cod_cred, ' ') and
              nvl(ind_cred_ori_m100_m500, ' ') =  nvl(p_ind_cred_ori, ' ') and
              nvl(aliq_m100_m500, 0)         =  nvl(p_aliq, 0) and
              nvl(aliq_quant_m100_m500, 0)   =  nvl(p_aliq_quant, 0) and
              nvl(cod_reg, ' ')         =  nvl(p_cod_reg, ' ') and
              nvl(ind_aj, ' ')          =  nvl(p_ind_aj, ' ') and
              nvl(cod_aj, ' ')          =  nvl(p_cod_aj, ' ') and
              nvl(num_doc, ' ')         =  nvl(p_num_doc, ' ')and
              nvl(dsc_aj, ' ')          =  nvl(p_dsc_aj, ' ') and
              cod_scp IS NULL ;

            --  lib_proc.add_log('linha_w '||linha_w,1);

         if linha_w = 1 then
            update EPC_REST_AJT_M110_M510
             set dt_ref = p_dt_ref ,
                 vl_aj  = p_vl_aj ,
                 texto  = p_texto
            where cod_empresa     = p_cod_empresa and
                  cod_estab       = p_cod_estab and
                  cod_tipo_livro  = p_cod_tipo_livro and
                  dat_apur_ini    = p_dat_apur_ini and
                  dat_apur_fim    = p_dat_apur_fim and
                  nvl(cod_reg_m100_m500, ' ')      = nvl(p_cod_reg_m100_m500, ' ') and
                  nvl(cod_cred_m100_m500, ' ')     = nvl(p_cod_cred, ' ') and
                  nvl(ind_cred_ori_m100_m500, ' ') = nvl(p_ind_cred_ori, ' ') and
                  nvl(aliq_m100_m500, 0)         = nvl(p_aliq, 0) and
                  nvl(aliq_quant_m100_m500, 0)   = nvl(p_aliq_quant, 0) and
                  nvl(cod_reg, ' ')                = nvl(p_cod_reg, ' ') and
                  nvl(ind_aj, ' ')                 = nvl(p_ind_aj, ' ') and
                  nvl(cod_aj, ' ')                 = nvl(p_cod_aj, ' ') and
                  nvl(num_doc, ' ')                = nvl(p_num_doc, ' ') and
                  nvl(dsc_aj, ' ')                 = nvl(p_dsc_aj, ' ') and
                  cod_scp IS NULL ;

         else
           select seq_EPC_REST_AJT_M110_M510.nextval into in_rest_m110_m510_w from dual;
           begin

            /* lib_proc.add_log('inserir dados na tabela de ajustes in_rest_m110_m510_w '||in_rest_m110_m510_w
            ||'p_cod_empresa '||p_cod_empresa
            ||'p_cod_estab '||p_cod_estab
            ||'p_cod_tipo_livro '||p_cod_tipo_livro
            ||'p_dat_apur_ini '||p_dat_apur_ini

             ,1);*/

           insert into EPC_REST_AJT_M110_M510
                     ( id_rest_m110_m510,
                       cod_empresa,
                       cod_estab,
                       cod_tipo_livro,
                       dat_apur_ini,
                       dat_apur_fim,
                       cod_reg_m100_m500,
                       cod_cred_m100_m500,
                       ind_cred_ori_m100_m500,
                       aliq_m100_m500,
                       aliq_quant_m100_m500,
                       cod_reg,
                       ind_aj,
                       cod_aj,
                       dt_ref,
                       vl_aj,
                       num_doc,
                       dsc_aj,
                       ind_gravacao,
                       texto,
                       cod_scp  )
                  values
                      (in_rest_m110_m510_w,
                       p_cod_empresa    ,
                       p_cod_estab     ,
                       p_cod_tipo_livro ,
                       p_dat_apur_ini   ,
                       p_dat_apur_fim   ,
                       p_cod_reg_m100_m500        ,
                       p_cod_cred      ,
                       p_ind_cred_ori   ,
                       p_aliq           ,
                       p_aliq_quant     ,
                       p_cod_reg        ,
                       p_ind_aj         ,
                       p_cod_aj         ,
                       p_dt_ref,
                       P_vl_aj,
                       p_num_doc,
                       p_dsc_aj,
                       p_ind_gravacao,
                       p_texto,
                       NULL         );

                       commit;
                exception when others then
                  lib_proc.add_log('Erro ao inserir dados na tabela de ajustes '||sqlerrm,1);
                end;

                commit;

         end if ;
      exception
       when others then
          pStatus   := -1;
          pMensagem := substr(sqlerrm,1,100)||nomeProc;
          lib_proc.add_log('FALHA',1);
          lib_proc.add_log(nomePkg || nomeProc,1);
          lib_proc.add_log(pMensagem,1);
          lib_proc.add_log('Falha na cópia dos lançamentos manuais para tabelas de restauração.',1);
     End;

   End insert_table_m110_m510;

Procedure insert_table_M220_M620 (p_cod_empresa    in varchar2
                                   , p_cod_estab      in varchar2
                                   , p_cod_tipo_livro in varchar2
                                   , p_dat_apur_ini   in date
                                   , p_dat_apur_fim   in date
                                   , p_cod_reg_m210_m610 in varchar2
                                   , p_cod_cont       in varchar2
                                   , p_aliq           in number
                                   , p_aliq_quant     in number
                                   , p_cod_reg        in varchar2
                                   , p_ind_aj         in varchar2
                                   , p_vl_aj          in number
                                   , p_cod_aj         in varchar2
                                   , p_num_doc        in varchar2
                                   , p_dsc_aj         in varchar2
                                   , p_dt_ref         in date
                                   , p_texto          in varchar2
                                   , pmensagem       out varchar2
                                   , pstatus         out varchar2)  is

    linha_w number;
    in_rest_M220_M620_w number;
    nomeProc constant varchar2(40) := '.insert_table_M220_M620';
    nomePkg  varchar2(200) := 'GSR_COTY_PIS_COF_AJU_MAN_CPROC';
    Begin
      pStatus := 0;
      Begin
        select count(*)
        into linha_w
        from epc_rest_ajt_m220_m620
        where cod_empresa     = p_cod_empresa and
              cod_estab       = p_cod_estab and
              cod_tipo_livro  = p_cod_tipo_livro and
              dat_apur_ini    = p_dat_apur_ini and
              dat_apur_fim    = p_dat_apur_fim and
              nvl(cod_reg_m210_m610, ' ')      = nvl(p_cod_reg_m210_m610, ' ') and
              nvl(cod_cont_m210_m610, ' ')     = nvl(p_cod_cont, ' ') and
              nvl(aliq_m210_m610, 0)         = nvl(p_aliq, 0) and
              nvl(aliq_quant_m210_m610, 0)   = nvl(p_aliq_quant, 0) and
              nvl(cod_reg, ' ')         = nvl(p_cod_reg, ' ') and
              nvl(ind_aj, ' ')          = nvl(p_ind_aj, ' ') and
              nvl(cod_aj, ' ')          = nvl(p_cod_aj, ' ') and
              nvl(num_doc, ' ')         = nvl(p_num_doc, ' ');

         if linha_w = 1 then
            update epc_rest_ajt_m220_m620
             set dt_ref = p_dt_ref ,
                 vl_aj  = p_vl_aj ,
                 descr_aj = p_dsc_aj ,
                 texto  = p_texto
            where cod_empresa     = p_cod_empresa and
                  cod_estab       = p_cod_estab and
                  cod_tipo_livro  = p_cod_tipo_livro and
                  dat_apur_ini    = p_dat_apur_ini and
                  dat_apur_fim    = p_dat_apur_fim and
                  nvl(cod_reg_m210_m610, ' ')      = nvl(p_cod_reg_m210_m610, ' ') and
                  nvl(cod_cont_m210_m610, ' ')     = nvl(p_cod_cont, ' ') and
                  nvl(aliq_m210_m610, 0)         = nvl(p_aliq, 0) and
                  nvl(aliq_quant_m210_m610, 0)   = nvl(p_aliq_quant, 0) and
                  nvl(cod_reg, ' ')         = nvl(p_cod_reg, ' ') and
                  nvl(ind_aj, ' ')          = nvl(p_ind_aj, ' ') and
                  nvl(cod_aj, ' ')          = nvl(p_cod_aj, ' ') and
                  nvl(num_doc, ' ')         = nvl(p_num_doc, ' ');

         else
           select seq_EPC_rest_AJT_M220_M620.nextval into in_rest_M220_M620_w from dual;

           insert into epc_rest_ajt_m220_m620
                     ( id_rest_m220_m620,
                       cod_empresa,
                       cod_estab,
                       cod_tipo_livro,
                       dat_apur_ini,
                       dat_apur_fim,
                       cod_reg_m210_m610,
                       cod_cont_m210_m610,
                       aliq_m210_m610,
                       aliq_quant_m210_m610,
                       cod_reg,
                       ind_aj,
                       vl_aj,
                       cod_aj,
                       num_doc,
                       descr_aj,
                       dt_ref,
                       texto  )
                  values
                      (in_rest_M220_M620_w,
                       p_cod_empresa    ,
                       p_cod_estab     ,
                       p_cod_tipo_livro ,
                       p_dat_apur_ini   ,
                       p_dat_apur_fim   ,
                       p_cod_reg_m210_m610        ,
                       p_cod_cont      ,
                       p_aliq           ,
                       p_aliq_quant     ,
                       p_cod_reg        ,
                       p_ind_aj         ,
                       P_vl_aj,
                       p_cod_aj         ,
                       p_num_doc,
                       p_dsc_aj,
                       p_dt_ref,
                       p_texto         );

         end if ;
      exception
       when others then
          pStatus   := -1;
          pMensagem := substr(sqlerrm,1,100)||nomeProc;
          lib_proc.add_log('FALHA',1);
          lib_proc.add_log(nomePkg || nomeProc,1);
          lib_proc.add_log(pMensagem,1);
          lib_proc.add_log('Falha na cópia dos lançamentos manuais para tabelas de restauração.',1);
     End;

   End insert_table_M220_M620;


  function removerCaracteresEspeciais(p_texto in varchar2) return varchar2 is
    result varchar2(2000);
    i      integer;
  begin
    result := p_texto;

    for i in 0..31 loop
      result := replace(result,chr(i),' ');
    end loop;

    return(result);
  end removerCaracteresEspeciais;

Function FormataValor_pc (Valor        In Varchar2,
                       vs_tipo          varchar2,      -- Tipo do Campo (Caracter, Numérico, Data, Texto Fixo etc)
                       vn_decimais      Integer,       -- Número de Casas Decimais
                       vn_tamanho       Integer,       -- Tamanho do Campo
                       vn_tamnhoMsaf    Integer,       -- Tamanho do campo no Mastersaf, usado p/ montagem da chave
                       IndCHave      In varchar2 Default 'N') Return Varchar2 Is

   NumSep          CONSTANT VARCHAR2(60) := 'nls_numeric_characters = '',.''';
   --NumSepAmericano CONSTANT VARCHAR2(60) := 'nls_numeric_characters = ''.,''';
   Numero Varchar2(100) := '9999999999999999999990';
   I      Integer;
   Result Varchar2(4000);
   --nomeProc constant varchar2(40) := '.FormataValor';
Begin

   If IndChave = 'N' Then
      If vs_tipo = 'C' Then
         result := removerCaracteresEspeciais((trim(valor)));
      Else
         if Valor is null then
            Return (Null);
         end if;

         If Nvl(vn_decimais,0) > 0 Then
            Numero := Numero || 'D' || Lpad('0',Nvl(vn_decimais,0),'0');
         Else
            If vn_tamanho > 0 Then
               Numero := Null;
               For I In 1..vn_tamanho Loop
                  Numero := Numero || '0';
               End Loop;
            End If;
         End If;
         -- OS2388-E: Alteração para tratar a formatação da chv_nfe.
         -- No layout este campo é Numérico de tamanho = 44.
         -- É o único campo do layout, sendo numérico de tamanho superior a 38 dígitos
         -- (Oracle o tipo Number tem tamanho máximo = 38).
         -- Este campo foi criado nas tabelas MasterSAF como Varchar2(80), pela limitação do Oracle.
         -- A função To_char não formata corretamente valor com mais de 40 dígitos.
         -- O tratamento de valor > 40 é somente necessário para o campo chv_nfe.  Todos os demais campos
         -- numéricos vão cair no tratamento  To_Char(....).
         If Length(Valor) > 40 Then
           Result := Lpad(Nvl(Ltrim(Rtrim(Valor)),'0'), vn_tamanho,'0');
         Else
           begin
             Result := To_Char(To_Number(Nvl(Ltrim(Rtrim(Valor)),0)),Numero,NumSep);
           exception
             when value_error then
               Result := To_Char(To_Number(Nvl(Ltrim(Rtrim(replace(Valor,',','.'))),0)),Numero,NumSep);
           end;
         End if;

         If INSTR(Result,',') > 0 AND SUBSTR(Result,INSTR(Result,',')+1) = 0 Then
           Result := SUBSTR(Result,1,INSTR(Result,',')-1);
         End If;
      End If;
   Else
      If vs_tipo = 'C' Then
         If Nvl(vn_tamnhoMsaf,0) = 0 Then
            Result := rpad(nvl(removerCaracteresEspeciais((trim(valor))),' '), Nvl(vn_tamanho, 0));
         Else
            Result := rpad(nvl(removerCaracteresEspeciais((trim(valor))),' '), vn_tamnhoMsaf);
         End If;
      Else
         -- OS2388-Oge: Alteração para tratar campos que são definidos como núméricos, mas são códigos e não valores.
         --             O código Nulo é diferente do código 000.
         --             Por isto esta função foi alterada para formatar os valor nulo com espaços e  não com zeros.
         --             Exempo: CST.
         --             Se o código do CST = nulo --> a formatação será = '   ' (3 espaços)
         --             Se o código do CST <> nulo --> a formatação será com zeros = '000'

         If Valor Is Null Then
             If Nvl(vn_tamnhoMsaf,0) = 0 Then
                Result := Rpad(Nvl(Valor,' '), Nvl(vn_tamanho, 0));
             Else
                Result := Rpad(Nvl(Valor,' '), vn_tamnhoMsaf);
             End If; -- teste
         else -- teste
           begin
             Result := Lpad(To_Char(To_Number(Nvl(Ltrim(Rtrim(Valor)),'0'))), Nvl(vn_tamnhoMsaf, Nvl(vn_tamanho,0)),'0');
           exception
             when value_error then
               Result := Lpad(To_Char(To_Number(Nvl(Ltrim(Rtrim(replace(Valor,',','.'))),'0'))), Nvl(vn_tamnhoMsaf, Nvl(vn_tamanho,0)),'0');
           end;
         End If; -- teste
         If INSTR(Result,',') > 0 AND SUBSTR(Result,INSTR(Result,',')+1) = 0 Then
           Result := SUBSTR(Result,1,INSTR(Result,',')-1);
         End If;
      End If;
   End If;

   Return (Result);
Exception
   When Value_Error Then
    /*  pkg_log.setCodRegistro(pLayoutCampo.NumReg);
      pkg_log.setLocalizacao(nomePkg || nomeProc);
      pkg_log.setMensagem('Erro de conversão na formatação do registro '     ||
                           pLayoutCampo.Bloco || pLayoutCampo.NumReg || ': '  ||
                          ' Campo = ' || pLayoutCampo.Campo || ' - Valor = ' ||
                           Valor || ' Tipo do Campo = ' || vs_tipo);
      pkg_log.setCriticidade('E');
      pkg_log.gravaLog;*/
      lib_proc.add_log('Erro de conversão na formatação do registro ',1);

      Return (Valor);
   When Others Then
     /* pkg_log.setCodRegistro(pLayoutCampo.NumReg);
      pkg_log.setLocalizacao(nomePkg || nomeProc);
      pkg_log.setMensagem('Erro não previsto durante formatação do registro ' ||
                          pLayoutCampo.Bloco || pLayoutCampo.NumReg || ', '   ||
                          ' campo ' || pLayoutCampo.Campo || '. ' ||
                          'Mensagem do banco de dados: ' || SQLERRM);
      pkg_log.setCriticidade('E');
      pkg_log.gravaLog;*/
      lib_proc.add_log('Erro não previsto durante formatação do registro ',1);

      Return (Valor);
End FormataValor_pc;


procedure restaura_lanctos_manuais(vs_cod_empresa varchar2
                         , vs_cod_estab   varchar2
                         , vd_data_ini   date
                         , vd_data_fim   date
                         ) is

vn_proc_id    integer;
mproc_id_proc integer;

begin




-- ***************************************** Restauracao de lancamentos manuais **********************************


  plog := '********** Restauracao de lancamentos manuais *****';
  --lib_proc.add_log('********** Restauracao de lancamentos manuais *****',1);
  insere_log(plog,1, mproc_id);

SELECT lib_proc_seq.NEXTVAL
  into vn_proc_id
  FROM dual;



-- Parametros
   INSERT INTO lib_processo ( proc_id
                            , sp_nome
                            , data_inicio
                            , cod_usuario
                            , situacao
                            , cod_empresa
                            , ind_prog )
                     VALUES ( vn_proc_id
                            , 'Epc_Rest_Ajt_Fproc'
                            , sysdate
                            , 'mastersaf'
                            , 'iniciado'
                            , mcod_empresa
                            , 'S' );

   -- Data Inicio
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'Data Inicial'
                              ,vd_data_ini
                              ,'Date'
                              ,'S'
                              ,vd_data_ini );


    -- Data Final
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'Data Final'
                              ,vd_data_fim
                              ,'Date'
                              ,'S'
                              ,vd_data_fim );


   -- M110 - Ajustes do Credito de PIS/PASEP Apurado
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M110 - Ajustes do Credito de PIS/PASEP Apurado'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');

   -- M211 - Sociedades Cooperativas - Composicao da Base de Calculo - PIS/PASEP
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M211 - Sociedades Cooperativas - Composicao da Base de Calculo - PIS/PASEP'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


   -- M220 - Ajustes da Contribuicao de PIS/PASEP Apurada
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M220 - Ajustes da Contribuicao de PIS/PASEP Apurada'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


  -- M230 - Informacoes Adicionais de Diferimento
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M230 - Informacoes Adicionais de Diferimento'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


  -- M300 - Contribuicao de PIS/PASEP Diferida em Periodos Anteriores - Valores a Pagar no Periodo
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M300 - Contribuicao de PIS/PASEP Diferida em Periodos Anteriores - Valores a Pagar no Periodo'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


 -- M510 - Ajustes do Credito de COFINS Apurado
 INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M510 - Ajustes do Credito de COFINS Apurado'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


 --M611 - Sociedades Cooperativas - Composicao da Base de Calculo - COFINS
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M611 - Sociedades Cooperativas - Composicao da Base de Calculo - COFINS'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


  -- M620 - Ajustes da Contribuicao de COFINS Apurada
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M620 - Ajustes da Contribuicao de COFINS Apurada'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


 -- M630 - Informacoes Adicionais de Diferimento
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M630 - Informacoes Adicionais de Diferimento'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


  -- M700 - COFINS Diferida em Periodos Anteriores - Valores a Pagar no Periodo
  INSERT INTO lib_proc_param  (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'M700 - COFINS Diferida em Periodos Anteriores - Valores a Pagar no Periodo'
                              ,'S'
                              ,'Varchar2'
                              ,'S'
                              ,'SIM');


   -- Estabelecimentos
   INSERT INTO lib_proc_param (procparam_id
                              ,proc_id
                              ,nome
                              ,valor
                              ,tipo
                              ,apresenta
                              ,valor_apresenta)
                       VALUES (lib_procparam_seq.NEXTVAL
                              ,vn_proc_id
                              ,'Estabelecimentos'
                              ,vs_cod_estab
                              ,'Varchar2'
                              ,'S'
                              ,vs_cod_estab);


   commit;


-- Geracao do processo

     --plog := '********** Execucao da Restauracao dos Lancamentos Manuais ***********';
     --insere_log(plog,1, mproc_id);
     --lib_proc.add_log(plog,1);

DECLARE

--mproc_id INTEGER;
mvartab LIB_PROC.varTab;

BEGIN


  FOR c1 IN (SELECT *
                   FROM lib_proc_param
                  WHERE proc_id = vn_proc_id AND UPPER( tipo ) = 'MULTISELECT'
               ORDER BY procparam_id ) LOOP

  mvartab(mvartab.count + 1) := c1.valor;

  END LOOP;


  LIB_PARAMETROS.Salvar( 'Empresa', vs_cod_empresa );
  LIB_PARAMETROS.Salvar( 'Usuario', musuario );
  LIB_PARAMETROS.Salvar( 'Aplicacao', 'SAFPISCOFINS.EXE' );
  LIB_PARAMETROS.Salvar( 'Modulo', 'SAFPISCOFINS' );
  LIB_PARAMETROS.Salvar( 'Conexao', 'msaf_v2@msaf' );
  LIB_PARAMETROS.Salvar( 'PROCORIG', vn_proc_id );


   mproc_id_proc := EPC_REST_AJT_FPROC.Executar( vd_data_ini
                                               , vd_data_fim
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , 'S'
                                               , vs_cod_estab );


  plog := 'Processo: '||mproc_id_proc||' - Data Ini:'||vd_data_ini||' - Data Fim:'||vd_data_fim;
  lib_proc.add_log(plog,1);
  --insere_log(plog,1, mproc_id);

   begin
    UPDATE lib_proc_param
       SET proc_id = mproc_id_proc
     WHERE proc_id = vn_proc_id;

    DELETE FROM lib_processo
     WHERE proc_id = vn_proc_id;

    commit;
   exception when others then
     plog := 'Erro ao excluir processo lib_processo '||sqlerrm;
     insere_log(plog,1, vn_proc_id);
     --lib_proc.add_log(plog,1);

   end;


END;

end;

procedure recalcula_apuracao(vn_id_reg_apur number
                           , mcod_empresa   varchar2
                           , vs_cod_estab   varchar2
                           , vd_data_ini    date
                           , vd_data_fim    date) is




STATUS integer;
MSGRETORNO varchar2(2000);


Begin

  BEGIN


  plog := '********** Recalcula a apuracao ***********';
  insere_log(plog,1, mproc_id);


  epc_parametros.setEstabCentr(mcod_empresa,vs_cod_estab);
  epc_parametros.setDadosIniciais;
  epc_parametros.setDataInicial(vd_data_ini);
  epc_parametros.setDatafinal(vd_data_fim);

-- executa esse update para as triggers reajustar o texto

update EPC_REG_AJT_M100_M500 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m105_m505 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m110_m510 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m200_m600 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m210_m610 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m400_m800 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m410_m810 set cod_reg = cod_reg where vn_by=1 ;


commit;

  begin
    Epc_Calculo_Apuracao.recalcularCOFINS_Manutencao( PID_REG => vn_id_reg_apur   ,STATUS=>STATUS,MSGRETORNO=>MSGRETORNO);

  exception when others then
    plog := sqlerrm;
    insere_log(plog,1, mproc_id);
   --lib_proc.add_log(plog,1);
  END;


  begin
    Epc_Calculo_Apuracao.recalcularCOFINS_Manutencao( PID_REG => vn_id_reg_apur   ,STATUS=>STATUS,MSGRETORNO=>MSGRETORNO);

  exception when others then
    plog := sqlerrm;
    insere_log(plog,1, mproc_id);
--    lib_proc.add_log(plog,1);
  END;


 plog := STATUS||'-'||MSGRETORNO;
 --lib_proc.add_log(plog,1);
 insere_log(plog,1, mproc_id);


   begin
     Epc_Calculo_Apuracao.recalcularPIS_Manutencao( PID_REG => vn_id_reg_apur   ,STATUS=>STATUS,MSGRETORNO=>MSGRETORNO);

  exception when others then
    plog := sqlerrm;
    --lib_proc.add_log(plog,1);
     insere_log(plog,1, mproc_id);
  END;


   begin
     Epc_Calculo_Apuracao.recalcularPIS_Manutencao( PID_REG => vn_id_reg_apur   ,STATUS=>STATUS,MSGRETORNO=>MSGRETORNO);

  exception when others then
    plog := sqlerrm;
    --lib_proc.add_log(plog,1);
     insere_log(plog,1, mproc_id);
  END;



  plog := STATUS||'-'||MSGRETORNO;
     insere_log(plog,1, mproc_id);

  end;

-- *************************** Fim recalculo apuracao ******************************************************

    plog := '********** Fim Recalculo da apuracao ***********';
    insere_log(plog,1, mproc_id);
    --lib_proc.add_log(plog,1);

update EPC_REG_AJT_M100_M500 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m105_m505 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m110_m510 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m200_m600 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m210_m610 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m400_m800 set cod_reg = cod_reg where vn_by=1 ;


update epc_reg_ajt_m410_m810 set cod_reg = cod_reg where vn_by=1 ;


commit;



end recalcula_apuracao;


procedure insere_log(vs_log  varchar2
                   , vn_nivel number
                   , mproc_id number) is



begin
           INSERT INTO lib_proc_log (proclog_id
                                   , proc_id
                                   , data
                                   , texto
                                   , nivel)
                             VALUES (LIB_PROCLOG_SEQ.NEXTVAL
                                   , mproc_id
                                   , SYSDATE
                                   , vs_log
                                   , vn_nivel);
          commit;



end;

  FUNCTION Parametros RETURN VARCHAR2 IS
    pstr VARCHAR2(5000);
    sqlText_perf varchar2(4000);
    sqlText_estab varchar2(4000);

  BEGIN

    mcod_empresa := LIB_PARAMETROS.RECUPERAR('EMPRESA');
    musuario     := LIB_PARAMETROS.Recuperar('Usuario');


    LIB_PROC.add_param(pstr, 'Data Ref:', 'date', 'textbox', 'S', null, 'mm/yyyy');

    sqlText_perf := 'select distinct param.id_parametros,param.id_parametros||'' - ''||param.descricao descricao from '||
               '  fpar_param_det            det1 '||
               ', fpar_parametros           param '||
               ', fpar_param_estab          festab '||
               'where param.nome_framework = ''GSR_COTY_AJUSTE_APUR_CPAR'' '||
               'and festab.cod_empresa = '''|| mcod_empresa ||''' '||
               'and det1.id_parametro = param.id_parametros '||
               'and festab.id_parametros = param.id_parametros '||
               'order by 1';


    -- :2
    lib_proc.add_param (pparam      => pstr,
                        ptitulo     => 'Perfil',
                        ptipo       => 'Varchar2',
                        pcontrole   => 'combobox',
                        pmandatorio => 'S',
                        pdefault    => null,
                        pmascara    => null,
                        pvalores    => sqlText_perf,
                        papresenta  => 'S',
                        phabilita   => null);



      /*LIB_PROC.add_param(pstr,
                         'Processo de Geracao dos Registros Executado',
                         'Varchar2',
                         'Checkbox',
                         'N',
				                 'N',
                         NULL,
                         NULL,
                         'S');*/



       sqlText_estab :=
               'SELECT DISTINCT a.Cod_Empresa_ou_Cod_Estab, a.Descricao ' ||
               'FROM VIEW_MULTI_SELECT_C a, ' ||
               '(select distinct cod_empresa,cod_estab from efd_dados_iniciais_piscof) b '||
               'WHERE b.cod_empresa = a.cod_empresa and b.cod_estab = nvl(trim(a.cod_estab),b.cod_estab) '||
               'AND (a.cod_Empresa = ''' || mcod_empresa ||''' and a.tipo = ''Estab'' ) ORDER BY 1, 2';


      lib_proc.add_param(pparam      => pstr,
                         ptitulo     => 'Empresa/Estabelecimento',
                         ptipo       => 'Varchar2',
                         pcontrole   => 'MultiProc',
                         pmandatorio => 'S',
                         pdefault    => null,
                         pvalores    => sqlText_estab,
                         papresenta  => 'S',
                         phabilita   => null);


    RETURN pstr;

  END;

  FUNCTION Nome RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Lancamentos Manuais PIS/COFINS - Ajuste de Credito PIS/COFINS';
  END;

  FUNCTION Tipo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'PIS COFINS';
  END;

  FUNCTION Versao RETURN VARCHAR2 IS
  BEGIN
    RETURN '1.0';
  END;

  FUNCTION Descricao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Ajuste de Credito PIS/COFINS';
  END;

  FUNCTION Modulo RETURN VARCHAR2 IS
  BEGIN
    RETURN 'Processos Customizados';
  END;

  FUNCTION Classificacao RETURN VARCHAR2 IS
  BEGIN
    RETURN 'PIS COFINS';
  END;


FUNCTION Executar (p_data_ref           date
                 , p_perfil             number
               --  , vs_ger_registros     varchar2
                -- , p_proc_estab_emp     varchar2
                 , p_cod_emp_estab      varchar2
                 )RETURN INTEGER IS


    /* Variaveis de Trabalho */
    mproc_id             integer;
    --vs_cod_estab         varchar2(6);
    vd_data_ref          date;
    vd_data_ini          date;
    vd_data_fim          date;

    vn_rel                   number:=1;
    vs_nome_rel              varchar2(3000);
    vs_cnpj_matriz           varchar2(18);
    vs_razao_social_matriz   estabelecimento.razao_social%type;
    vs_cod_estab_matriz      estabelecimento.cod_estab%type;
    vs_nome_interface        varchar2(300);
    --vs_uf                    varchar2(2);

      --vs_descr_erro   varchar2(300);
      vs_erro_apur         exception;

  BEGIN


    vd_data_ref := to_date('01/'||to_char(p_data_ref,'MM/YYYY'),'dd/mm/yyyy');
    vd_data_ini := to_date('01/'||to_char(p_data_ref,'MM/YYYY'),'dd/mm/yyyy');

    vd_data_ref := last_day(vd_data_ref);
    vd_data_fim := last_day(vd_data_ref);

    mcod_empresa := LIB_PARAMETROS.RECUPERAR('EMPRESA');
    musuario     := LIB_PARAMETROS.Recuperar('Usuario');

    mproc_id := LIB_PROC.new('GSR_COTY_PIS_COF_AJU_MAN_CPROC', 48, 150);

    LIB_PROC.add_tipo(mproc_id, vn_rel, 'Ajustes Mensais', 3,48,150);

    LIB_PROC.ADD_LOG('Log de Processo - Ajustes Mensais ', 1);
    LIB_PROC.ADD_LOG('EMPRESA: ' || mcod_empresa, 1);
    LIB_PROC.ADD_LOG('USUARIO: ' || musuario, 1);
    LIB_PROC.ADD_LOG('.     Data da Geracao: '||TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'), 1);
    LIB_PROC.ADD_LOG('.     Parametros Informados: ', 1);
    LIB_PROC.ADD_LOG('.     Periodo Referencia: ' || TO_CHAR(p_data_ref, 'DD/MM/YYYY'), 1);


    begin
     select estab.razao_social
          , substr(cgc, 1, 2) || '.' || substr(cgc, 3, 3) || '.' ||
            substr(cgc, 6, 3) || '/' || substr(cgc, 9, 4) || '-' ||
            substr(cgc, 13, 2)
          , estab.cod_estab
       into vs_razao_social_matriz
          , vs_cnpj_matriz
          , vs_cod_estab_matriz
      from estabelecimento estab
         , ESTADO est
     where estab.cod_empresa  = mcod_empresa
       and estab.ident_estado = est.ident_estado
       and estab.ind_matriz_filial = 'M';
    exception when others then
     lib_proc.add_log('Erro ao buscar dados da Matriz: '||mcod_empresa||' - '||sqlerrm,1);
    end;

--    SAF_TOT_OP_COMMIT(vn_num_op_commit);


    lib_proc.add_log('INICIADO: ' || TO_CHAR(SYSDATE, 'HH24:MI:SS'),1);

    vs_nome_rel := 'Processo de Ajustes Mensais da Apuração';
    vs_nome_interface := 'PIS/COFINS';

    cabecalho(vs_nome_rel
             ,vn_rel
             ,vs_razao_social_matriz
             ,vs_cnpj_matriz
             ,mproc_id
             ,vd_data_ini
             ,vd_data_fim
             ,vs_nome_interface

             );


    setEstabGeracao (mcod_empresa, p_cod_emp_estab);


   LIB_PROC.ADD_TIPO(mproc_id, 2, 'REL_AJUSTES_REALIZADOS_'||p_cod_emp_estab||'_'||TO_CHAR(vd_data_ref, 'MMYYYY')||'.CSV', 2);

   mLinha := LIB_STR.w('', '', 1);
   mLinha := 'ID_REG_M100_M500;'
                ||'ID_REG_M110_M510;'
                ||'COD_REG;'
                ||'IND_AJ;'
                ||'COD_AJ;'
                ||'DT_REF;'
                ||'VL_AJ;'
                ||'NUM_DOC;'
                ||'DSC_AJ;'
                ||'IND_GRAVACAO;' ;
   lib_proc.add(mLinha, null, null, 2);


   processa_dados_M110_M510(mcod_empresa
                           , p_cod_emp_estab
                           , vd_data_ini
                           , vd_data_fim
                           , p_perfil);


   /*if vs_ger_registros = 'S' then

   begin
    begin
     select id_reg
       into vn_id_reg_apur
       from epc_apuracao
      where dat_apur_ini = to_date(vd_data_ini,'dd/mm/yyyy')
        and dat_apur_fim = to_date(vd_data_fim,'dd/mm/yyyy')
        and cod_estab    = p_cod_emp_estab
        and cod_empresa  = mcod_empresa;

    exception when others then

      raise vs_erro_apur;
    end;

-- ************************* Restaura Lanctos Manuais *********************************************
   begin
    restaura_lanctos_manuais(mcod_empresa, p_cod_emp_estab, vd_data_ini, vd_data_fim);
   exception when others then
     plog := 'Erro ao Restaurar Lancamentos Manuais '||substr(sqlerrm,1,300);
     insere_log(plog,1, mproc_id);

     --lib_proc.add_log('Erro ao Restaurar Lancamentos Manuais '||sqlerrm,1);
   end;

-- ************************* Recalcula a apuracao opos restaurar os lancamentos manuais *************


--    plog := '********** Atualiza Utilizacao de Credito ***********';
    --lib_proc.add_log(plog,1);
--    insere_log(plog,1, mproc_id);

-- atualiza utilizacao de credito

    for mreg in (select * from EPC_REG_AJT_M100_M500 where id_reg = vn_id_reg_apur) loop

    UPDATE EPC_REG_AJT_M100_M500
       SET IND_DESC_CRED = '0'
         , VL_CRED_DESC  = VL_CRED_DISP
         , VL_CRED_DISP  = 0
         , SLD_CRED      = 0
         , IND_GRAVACAO  = '7'
    WHERE ID_REG           = mreg.id_reg
      AND ID_REG_M100_M500 = mreg.ID_REG_M100_M500
      AND COD_REG          = mreg.COD_REG
      AND COD_CRED         = mreg.COD_CRED
      AND IND_CRED_ORI     = mreg.IND_CRED_ORI
      AND ALIQ             = mreg.ALIQ;
   commit;

    end loop;
    commit;


 -- Roda tres Vezes a apuracao pois na primeira vez ele ajusta o m100,  e na segunda o m200 com os ajustes
 -- recalculando a apuracao
     plog := 'Recalculando a Apuracao data_ini '||vd_data_ini||' Data Fim:'||vd_data_fim||' - '||vs_descr_erro;
     insere_log(plog,1, mproc_id);

     begin

      recalcula_apuracao(vn_id_reg_apur,  mcod_empresa,p_cod_emp_estab,vd_data_ini,vd_data_fim);

      recalcula_apuracao(vn_id_reg_apur,  mcod_empresa,p_cod_emp_estab,vd_data_ini,vd_data_fim);

      recalcula_apuracao(vn_id_reg_apur,  mcod_empresa,p_cod_emp_estab,vd_data_ini,vd_data_fim);
     exception when others then
       vs_descr_erro := substr(sqlerrm,1,500);
       plog := 'Erro ao Recalcular a Apuracao  data_ini '||vd_data_ini||' Data Fim:'||vd_data_fim||' - '||vs_descr_erro;
       insere_log(plog,1, mproc_id);

     end;

   exception when vs_erro_apur then
     vs_descr_erro := substr(sqlerrm,1,500);
     plog := 'Erro ao buscar Apuração, id_reg epc_apuracao data_ini '||vd_data_ini||' Data Fim:'||vd_data_fim||' - '||vs_descr_erro;
     insere_log(plog,1, mproc_id);

     plog := 'Verifique se realmente foi Gerado os Registros do SPED Contribuicoes no modulo SPED Contribuicoes ';       --
     insere_log(plog,1, mproc_id);

--        lib_proc.add_log('Erro ao buscar Apuração, id_reg epc_apuracao data_ini '||vd_data_ini||' Data Fim:'||vd_data_fim||' - '||vs_descr_erro,1);
--        lib_proc.add_log('Verifique se realmente foi Gerado os Registros do SPED Contribuicoes no modulo SPED Contribuicoes ',1);       -- plog := 'Erro ao buscar id_reg epc_apuracao data_ini '||vd_data_ini||' Data Fim:'||vd_data_fim||' - '||vs_descr_erro;

     when others then
        plog := substr(sqlerrm,1,300);
       -- lib_proc.add_log('Erro '||sqlerrm,1);
        insere_log(plog,1, mproc_id);
        --plog := 'Estab '||vs_cod_estab;
        --insere_log(plog,1, mproc_id);

   end;




  end if;*/



    final_html(vn_rel);

    plog := 'Processo Finalizado com sucesso';
    insere_log(plog,1, mproc_id);

     UPDATE lib_processo
      SET    situacao = 'encerrado',
             data_fim = SYSDATE
      WHERE  proc_id = mproc_id;
      commit;
    --LIB_PROC.CLOSE();
    RETURN mproc_id;

END;



END GSR_COTY_PIS_COF_AJU_MAN_CPROC;
/
