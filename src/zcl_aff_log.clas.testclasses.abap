CLASS ltcl_log_unit_test DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA:
      test_component_name TYPE string,
      log                 TYPE REF TO zif_aff_log,
      message             TYPE symsg,
      message_2           TYPE symsg.

    METHODS: setup,
      add_info FOR TESTING RAISING cx_static_check,
      add_warning FOR TESTING RAISING cx_static_check,
      add_error FOR TESTING RAISING cx_static_check,
      add_t100_exception FOR TESTING RAISING cx_static_check,
      joins_log FOR TESTING RAISING cx_static_check,
      clears_log FOR TESTING RAISING cx_static_check,
      get_max_severity FOR TESTING RAISING cx_static_check,
      has_messages FOR TESTING RAISING cx_static_check,
      two_messages_for_one_object FOR TESTING RAISING cx_static_check,
      add_catched_exception FOR TESTING RAISING cx_static_check,
      add_classic_exception FOR TESTING RAISING cx_static_check,
      get_sy_message FOR TESTING RAISING cx_static_check,
      add_exception_as_info FOR TESTING RAISING cx_static_check,
      assert_message
        IMPORTING
          act_message    TYPE zif_aff_log=>ty_log_out
          type           TYPE c
          exp_message    TYPE symsg
          component_name TYPE string OPTIONAL.
ENDCLASS.


CLASS ltcl_log_unit_test IMPLEMENTATION.

  METHOD setup.
    test_component_name = 'TEST_COMPONENT'.
    log = NEW zcl_aff_log( ).
    message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 msgv1 = 'TEST' ).
    message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 1 msgv1 = 'TEST' ).
  ENDMETHOD.


  METHOD add_info.
    log->add_info( message = message component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ] type = 'I' exp_message = message ).
  ENDMETHOD.


  METHOD add_warning.
    log->add_warning( message = message component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ] type = 'W' exp_message = message ).
  ENDMETHOD.


  METHOD add_error.
    log->add_error( message = message component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ] type = 'E' exp_message = message ).
  ENDMETHOD.


  METHOD add_t100_exception.
    DATA(previous) = NEW zcx_aff_tools( textid = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).
    DATA(exception) = NEW zcx_aff_tools( textid = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 ) previous = previous ).

    log->add_exception( exception = exception component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ] type = 'E' exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 ) ).
    assert_message( act_message = messages[ 2 ] type = 'E' exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).
  ENDMETHOD.


  METHOD add_catched_exception.
    TRY.
        RAISE EXCEPTION TYPE zcx_aff_tools MESSAGE e100(zaff_tools) WITH '1' '2' '3' '4'.
      CATCH zcx_aff_tools INTO DATA(exception).
        log->add_exception( exception = exception component_name = test_component_name ).
    ENDTRY.

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ]
                    type        = 'E'
                    exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 msgv1 = '1' msgv2 = '2' msgv3 = '3' msgv4 = '4' ) ).
  ENDMETHOD.


  METHOD add_classic_exception.
    DATA(exception) = NEW zcx_aff_tools( textid = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).

    log->add_exception( exception = exception component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ]
                    type        = 'E'
                    exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).
  ENDMETHOD.


  METHOD add_exception_as_info.
    DATA(previous) = NEW zcx_aff_tools( textid = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).
    DATA(exception) = NEW zcx_aff_tools( textid = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 ) previous = previous ).

    log->add_exception( exception = exception message_type = zif_aff_log=>c_message_type-info component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( messages ) ).
    assert_message( act_message = messages[ 1 ] type = 'I' exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 100 ) ).
    assert_message( act_message = messages[ 2 ] type = 'I' exp_message = VALUE #( msgid = 'ZAFF_TOOLS' msgno = 101 ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'I' act = log->get_max_severity( ) ).
  ENDMETHOD.


  METHOD joins_log.
    log->add_warning( message = message component_name = test_component_name ).
    DATA(log2) = CAST zif_aff_log( NEW zcl_aff_log( ) ).
    DATA(test_element_name2) = `TEST_COMPONENT2`.
    log2->add_error( message = message_2 component_name = test_element_name2 ).

    log->join( log2 ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( messages ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'E' act = log->get_max_severity( ) ).
    assert_message( act_message = messages[ 1 ] type = 'W' exp_message = message ).
    assert_message( act_message = messages[ 2 ] type = 'E' exp_message = message_2 component_name = test_element_name2 ).
  ENDMETHOD.


  METHOD clears_log.
    log->add_error( message = message component_name = test_component_name ).
    log->clear( ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lines( messages ) ).
  ENDMETHOD.


  METHOD get_max_severity.
    cl_abap_unit_assert=>assert_equals( exp = '' act = log->get_max_severity( ) ).

    log->add_info( message = message component_name = test_component_name ).
    cl_abap_unit_assert=>assert_equals( exp = 'I' act = log->get_max_severity( ) ).

    log->add_warning( message = message component_name = test_component_name ).
    cl_abap_unit_assert=>assert_equals( exp = 'W' act = log->get_max_severity( ) ).

    log->add_error( message = message component_name = test_component_name ).
    cl_abap_unit_assert=>assert_equals( exp = 'E' act = log->get_max_severity( ) ).

    log->add_exception( exception = NEW zcx_aff_tools( ) component_name = test_component_name ).
    cl_abap_unit_assert=>assert_equals( exp = 'E' act = log->get_max_severity( ) ).

    log->add_info( message = message component_name = test_component_name ).
    log->add_warning( message = message component_name = test_component_name ).
    cl_abap_unit_assert=>assert_equals( exp = 'E' act = log->get_max_severity( ) ).
  ENDMETHOD.


  METHOD has_messages.
    cl_abap_unit_assert=>assert_false( log->has_messages( ) ).

    log->add_info( message = message component_name = test_component_name ).
    cl_abap_unit_assert=>assert_true( log->has_messages( ) ).
  ENDMETHOD.


  METHOD two_messages_for_one_object.
    log->add_info( message = message component_name = test_component_name ).
    log->add_info( message = message_2 component_name = test_component_name ).

    DATA(messages) = log->get_messages( ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( messages ) ).
  ENDMETHOD.


  METHOD assert_message.
    IF component_name IS SUPPLIED.
      cl_abap_unit_assert=>assert_equals( exp = component_name act = act_message-component_name ).
    ELSE.
      cl_abap_unit_assert=>assert_equals( exp = test_component_name act = act_message-component_name ).
    ENDIF.
    cl_abap_unit_assert=>assert_equals( exp = type act = act_message-type ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE #( BASE exp_message msgty = type ) act = act_message-message ).
  ENDMETHOD.


  METHOD get_sy_message.
    MESSAGE i000(zaff_tools) WITH '1' '2' '3' '4' INTO DATA(message) ##NEEDED.
    DATA(act_message) = zcl_aff_log=>get_sy_message( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE symsg( msgid = 'ZAFF_TOOLS' msgno = '000' msgty = 'I' msgv1 = '1' msgv2 = '2' msgv3 = '3' msgv4 = '4' ) act = act_message ).

    MESSAGE e001(zaff_tools) INTO message.
    act_message = zcl_aff_log=>get_sy_message( ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE symsg( msgid = 'ZAFF_TOOLS' msgno = '001' msgty = 'E' ) act = act_message ).
  ENDMETHOD.

ENDCLASS.
