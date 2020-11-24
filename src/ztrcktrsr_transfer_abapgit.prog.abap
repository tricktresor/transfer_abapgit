REPORT ztrcktrsr_transfer_abapgit.

PARAMETERS p_repo TYPE zabapgit-value OBLIGATORY MATCHCODE OBJECT zabapgit_repo.
PARAMETERS p_file TYPE text100        OBLIGATORY LOWER CASE.
SELECTION-SCREEN PUSHBUTTON /35(30) TEXT-get USER-COMMAND $get.

SELECTION-SCREEN SKIP 1.
PARAMETERS p_gitusr TYPE string DEFAULT '' LOWER CASE.
PARAMETERS p_gitpwd TYPE string.
SELECTION-SCREEN PUSHBUTTON /35(30) TEXT-put USER-COMMAND $put.

INITIALIZATION.
  DATA(dock) = NEW cl_gui_docking_container( side = cl_gui_docking_container=>dock_at_bottom ratio = 70 ).
  DATA(text) = NEW cl_gui_textedit( parent = dock ).
  text->set_readonly_mode( 0 ).

  p_gitusr = zcl_abapgit_user_master_record=>get_instance( sy-uname  )->get_email( ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_filename.

AT SELECTION-SCREEN OUTPUT.

  LOOP AT SCREEN.
    IF screen-name = 'P_GITPWD'.
      screen-invisible = '1'.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

AT SELECTION-SCREEN.
  CASE sy-ucomm.
    WHEN '$GET'.
      PERFORM get USING p_file.
    WHEN '$PUT'.
      PERFORM put USING p_file.
  ENDCASE.

FORM get USING file TYPE text100.

  CHECK file IS NOT INITIAL.

  TRY.

      DATA(lo_online) = CAST zcl_abapgit_repo_online( zcl_abapgit_repo_srv=>get_instance( )->get( p_repo ) ).

      DATA(lt_files) = lo_online->get_files_remote( ).

      DATA(lv_data) = zcl_abapgit_convert=>xstring_to_string_utf8( iv_data = lt_files[ filename = file ]-data ).

      text->set_textstream( text = lv_data ).
      cl_gui_cfw=>flush( ).

    CATCH zcx_updownci_exception INTO DATA(lx_updownci).
      WRITE: / lx_updownci->iv_text.
    CATCH cx_static_check INTO DATA(lx_error).
      WRITE: / 'Error'.
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.

ENDFORM.

FORM put USING file TYPE text100.

  TRY.
      text->get_textstream(
        IMPORTING
          text                   = DATA(lv_adoc) ).
      cl_gui_cfw=>flush( ).

      DATA(lo_online) = CAST zcl_abapgit_repo_online( zcl_abapgit_repo_srv=>get_instance( )->get( p_repo ) ).

      DATA(lt_files) = lo_online->get_files_remote( ).
      DATA(lv_data) = zcl_abapgit_convert=>string_to_xstring_utf8( lv_adoc ).
      DATA(lv_filename) = |{ file }|.
      READ TABLE lt_files WITH KEY filename = lv_filename data = lv_data TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        DATA(ls_comment) = VALUE zif_abapgit_definitions=>ty_comment(
          committer-name  = sy-uname
          committer-email = |{ sy-uname }@localhost|
          comment         = 'Updated' ).

      ELSE.
        ls_comment = VALUE zif_abapgit_definitions=>ty_comment(
          committer-name  = sy-uname
          committer-email = |{ sy-uname }@localhost|
          comment         = 'Created' ).
      ENDIF.

      DATA(lo_stage) = NEW zcl_abapgit_stage(
          iv_merge_source = lo_online->get_current_remote( ) ).

      lo_stage->add(
        iv_path     = '/'
        iv_filename = lv_filename
        iv_data     = lv_data ).

      DATA(lt_objects) = lo_online->get_objects( ).
      DATA(lv_parent)  = lt_objects[ type = 'commit' ]-sha1.
*
*      data(f) = new ZCL_ABAPGIT_GIT_BRANCH_LIST( ).
**      f->find_by_name

      zcl_abapgit_git_porcelain=>push(
        EXPORTING
          is_comment     = ls_comment
          io_stage       = lo_stage
          it_old_objects = lt_objects
          iv_parent      = lv_parent
          iv_url         = lo_online->get_url( )
          iv_branch_name = lo_online->get_selected_branch( ) ).

    CATCH zcx_updownci_exception INTO DATA(lx_updownci).
      WRITE: / lx_updownci->iv_text.
    CATCH cx_static_check INTO DATA(lx_error).
      WRITE: / 'Error'.
      MESSAGE lx_error TYPE 'E'.
  ENDTRY.

ENDFORM.

FORM password_popup
        USING iv_repo_url
        CHANGING cv_user cv_pass.
  cv_user = p_gitusr.
  cv_pass = p_gitpwd.
ENDFORM.

FORM f4_filename.

  DATA shlp TYPE shlp_descr.
  CALL FUNCTION 'F4IF_GET_SHLP_DESCR'
    EXPORTING
      shlpname = 'ZABAPGIT_FILE'
    IMPORTING
      shlp     = shlp.
  DATA dynprofields TYPE STANDARD TABLE OF dynpread.
  CALL FUNCTION 'DYNP_VALUES_READ'
    EXPORTING
      dyname     = sy-repid
      dynumb     = sy-dynnr
      request    = 'A'
    TABLES
      dynpfields = dynprofields
    EXCEPTIONS
      OTHERS     = 11.
  IF sy-subrc = 0.
    shlp-interface[ shlpfield = 'REPO' ]-value        = dynprofields[ fieldname = 'P_REPO' ]-fieldvalue.
    shlp-interface[ shlpfield = 'FILENAME' ]-valfield = 'P_FILE'.
  ENDIF.

  DATA return_values TYPE tfw_ddshretval_tab.

  CALL FUNCTION 'F4IF_START_VALUE_REQUEST'
    EXPORTING
      shlp          = shlp
    TABLES
      return_values = return_values.

  TRY.
      dynprofields[ fieldname = 'P_FILE' ]-fieldvalue = return_values[ retfield = 'P_FILE' ]-fieldval.

      CALL FUNCTION 'DYNP_VALUES_UPDATE'
        EXPORTING
          dyname     = sy-repid
          dynumb     = sy-dynnr
        TABLES
          dynpfields = dynprofields " Screen field value reset table
        EXCEPTIONS
          OTHERS     = 8.
    CATCH cx_sy_itab_line_not_found ##no_handler.
  ENDTRY.

ENDFORM.
