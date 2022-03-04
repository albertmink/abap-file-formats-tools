CLASS zcl_aff_abap_doc_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS: BEGIN OF abap_doc_annotation,
                 callback_class    TYPE string VALUE `$callbackClass`,
                 default           TYPE string VALUE `$default`,
                 values            TYPE string VALUE `$values`,
                 required          TYPE string VALUE `$required`,
                 show_always       TYPE string VALUE `$showAlways`,
                 minimum           TYPE string VALUE `$minimum`,
                 maximum           TYPE string VALUE `$maximum`,
                 exclusive_minimum TYPE string VALUE `$exclusiveMinimum`,
                 exclusive_maximum TYPE string VALUE `$exclusiveMaximum`,
                 max_length        TYPE string VALUE `$maxLength`,
                 min_length        TYPE string VALUE `$minLength`,
                 multiple_of       TYPE string VALUE `$multipleOf`,
               END OF abap_doc_annotation.

    TYPES:
      BEGIN OF abap_doc,
        required          TYPE abap_bool,
        showalways        TYPE abap_bool,
        title             TYPE string,
        description       TYPE string,
        enumvalues_link   TYPE string,
        minimum           TYPE string,
        maximum           TYPE string,
        exclusive_minimum TYPE string,
        exclusive_maximum TYPE string,
        multiple_of       TYPE string,
        default           TYPE string,
        min_length        TYPE string,
        max_length        TYPE string,
        callback_class    TYPE string,
      END OF abap_doc.

    METHODS: parse
      IMPORTING
        component_name        TYPE string
        to_parse              TYPE string
      CHANGING
        log                   TYPE REF TO if_aff_log
      RETURNING
        VALUE(found_abap_doc) TYPE abap_doc.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_mixed_table_entry,
        offset  TYPE i,
        length  TYPE i,
        is_link TYPE abap_boolean,
      END OF ty_mixed_table_entry,
      tt_mixed_table_entry TYPE SORTED TABLE OF ty_mixed_table_entry WITH UNIQUE KEY offset.

    DATA abap_doc_string TYPE string.
    DATA parser_log TYPE REF TO if_aff_log.
    DATA component_name TYPE string.
    DATA decoded_abap_doc TYPE abap_doc.
    DATA description_warning_is_needed TYPE abap_boolean.

    METHODS:
      parse_title,
      parse_description,
      remove_leading_trailing_spaces
        CHANGING string_to_work_on TYPE string,
      parse_annotations,
      parse_callback_class,
      get_annotation_value
        IMPORTING
          length                  TYPE i
          offset                  TYPE i
          to_decode               TYPE string
          length_of_annotation    TYPE i
          remove_whitespaces      TYPE abap_boolean
        RETURNING
          VALUE(annotation_value) TYPE string,
      parse_default,
      parse_enum_values,
      parse_required,
      parse_show_always,
      parse_number_annotations
        IMPORTING
          key_word TYPE string,
      get_number_annotation
        IMPORTING
          annotation_name TYPE string
        RETURNING
          VALUE(number)   TYPE string,
      check_next_word
        IMPORTING
          offset        TYPE i
          text_to_check TYPE string,
      write_description_message,
      check_redundant_annotations.

ENDCLASS.


CLASS zcl_aff_abap_doc_parser IMPLEMENTATION.


  METHOD parse.
    CLEAR description_warning_is_needed.
    CLEAR decoded_abap_doc.
    abap_doc_string = to_parse.
    me->component_name = component_name.
    parser_log = log.
    parse_title( ).
    parse_annotations( ).
    parse_description( ).
    found_abap_doc = decoded_abap_doc.
    write_description_message( ).
  ENDMETHOD.


  METHOD parse_title.
    REPLACE ALL OCCURRENCES OF PCRE `[\s]*(<p[\s]+class="shorttext([\s]+synchronized)?"([\s]+lang="[a-zA-Z]{2}")?[\s]*>)[\s]*`
        IN abap_doc_string WITH `<p class="shorttext">` ##NO_TEXT.
    FIND ALL OCCURRENCES OF PCRE `<p\sclass="shorttext">.*?</p>` IN abap_doc_string RESULTS DATA(result_table).
    IF lines( result_table ) = 0.
      RETURN.
    ELSEIF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH `'Title'` component_name INTO DATA(message) ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(offset) = result_table[ 1 ]-offset.
    IF offset <> 0.
      MESSAGE i113(saff_core) WITH component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(length) = result_table[ 1 ]-length.
    DATA(title) = abap_doc_string+offset(length).
    REPLACE `</p>` IN title WITH ``.
    REPLACE `<p class="shorttext">` IN title WITH ``.
    remove_leading_trailing_spaces( CHANGING string_to_work_on = title ).
    decoded_abap_doc-title = title.
    REPLACE ALL OCCURRENCES OF PCRE `[\s]*<p\sclass="shorttext">.*?</p>[\s]*` IN abap_doc_string WITH ``.
  ENDMETHOD.


  METHOD parse_description.
    FIND FIRST OCCURRENCE OF PCRE `(\$callbackClass|\$default|\$values|\$required|\$showAlways|\$minimum|\$maximum|\$exclusiveMinimum|\$exclusiveMaximum|\$multipleOf|\$maxLength|\$minLength)`
      IN abap_doc_string MATCH OFFSET DATA(offset).
    IF sy-subrc = 0.
      DATA(description) = abap_doc_string+0(offset).
      remove_leading_trailing_spaces( CHANGING string_to_work_on = description ).
      decoded_abap_doc-description = description.
    ELSE.
      remove_leading_trailing_spaces( CHANGING string_to_work_on = abap_doc_string ).
      decoded_abap_doc-description = abap_doc_string.
    ENDIF.
  ENDMETHOD.


  METHOD parse_annotations.
    FIND ALL OCCURRENCES OF PCRE `\$[a-zA-Z]+` IN abap_doc_string RESULTS DATA(result_table) ##NO_TEXT.
    DATA(modified_abap_doc_string) = abap_doc_string.
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      DATA(offset) = <entry>-offset.
      DATA(length) = <entry>-length.
      DATA(key_word) = abap_doc_string+offset(length).
      CASE key_word.
        WHEN abap_doc_annotation-callback_class.
          parse_callback_class( ).
        WHEN abap_doc_annotation-default.
          parse_default( ).
        WHEN abap_doc_annotation-values.
          parse_enum_values( ).
        WHEN abap_doc_annotation-required.
          parse_required( ).
        WHEN abap_doc_annotation-show_always.
          parse_show_always( ).
        WHEN abap_doc_annotation-minimum OR abap_doc_annotation-maximum OR abap_doc_annotation-exclusive_minimum OR abap_doc_annotation-exclusive_maximum
             OR abap_doc_annotation-max_length OR abap_doc_annotation-multiple_of OR abap_doc_annotation-min_length.
          parse_number_annotations( key_word = key_word ).
        WHEN OTHERS.
          REPLACE key_word IN modified_abap_doc_string WITH ''.
          MESSAGE w108(saff_core) WITH key_word component_name INTO DATA(message) ##NEEDED.
          parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
      ENDCASE.
    ENDLOOP.
    check_redundant_annotations( ).
    abap_doc_string = modified_abap_doc_string.
  ENDMETHOD.

  METHOD parse_callback_class.
    IF decoded_abap_doc-callback_class IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(string_to_parse) = abap_doc_string.
    REPLACE ALL OCCURRENCES OF PCRE `\$callbackClass[\s]*(:[\s]*)?\{[\s]*@link` IN string_to_parse WITH `\$callbackClass\{@link`.
    FIND ALL OCCURRENCES OF PCRE `\$callbackClass\{@link[^\}]+\}` IN string_to_parse RESULTS DATA(result_table).
    IF lines( result_table ) = 0.
      MESSAGE w109(saff_core) WITH abap_doc_annotation-callback_class component_name INTO DATA(message) ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
      RETURN.
    ENDIF.
    IF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH abap_doc_annotation-callback_class component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(offset_found) = result_table[ 1 ]-offset.
    DATA(length_found) = result_table[ 1 ]-length.
    decoded_abap_doc-callback_class = get_annotation_value( length = length_found - 1 offset = offset_found to_decode = string_to_parse length_of_annotation = 20 remove_whitespaces = abap_true ).
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      check_next_word( offset = <entry>-offset + <entry>-length text_to_check = string_to_parse ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_annotation_value.
    DATA(step) = offset + length_of_annotation.
    DATA(length_of_annotation_value) = length - length_of_annotation.
    DATA(value) = to_decode+step(length_of_annotation_value).
    IF remove_whitespaces = abap_true.
      remove_leading_trailing_spaces( CHANGING string_to_work_on = value ).
    ENDIF.
    annotation_value = value.
  ENDMETHOD.


  METHOD parse_default.
    IF decoded_abap_doc-default IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(string_to_parse) = abap_doc_string.
    REPLACE ALL OCCURRENCES OF PCRE `\$default[\s]*(:[\s]*)?'` IN string_to_parse WITH `\$default'`.
    REPLACE ALL OCCURRENCES OF PCRE `\$default[\s]*(:[\s]*)?\{[\s]*@link` IN string_to_parse WITH `\$default\{@link`.

    FIND ALL OCCURRENCES OF PCRE `\$default'[^']*'` IN string_to_parse RESULTS DATA(result_table_value).
    FIND ALL OCCURRENCES OF PCRE `\$default\{@link[^\}]+\}` IN string_to_parse RESULTS DATA(result_table_link).

    DATA mixed_result_table TYPE tt_mixed_table_entry.
    LOOP AT result_table_value ASSIGNING FIELD-SYMBOL(<default_value>).
      INSERT VALUE #( offset = <default_value>-offset
                      length = <default_value>-length
                      is_link = abap_false ) INTO TABLE mixed_result_table.
    ENDLOOP.
    LOOP AT result_table_link ASSIGNING FIELD-SYMBOL(<default_link>).
      INSERT VALUE #( offset = <default_link>-offset length = <default_link>-length is_link = abap_true ) INTO TABLE mixed_result_table.
    ENDLOOP.

    IF lines( mixed_result_table ) = 0.
      MESSAGE w109(saff_core) WITH abap_doc_annotation-default component_name INTO DATA(message) ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
      RETURN.
    ENDIF.
    IF lines( mixed_result_table ) > 1.
      MESSAGE i107(saff_core) WITH abap_doc_annotation-default component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(warning_set) = abap_false.
    LOOP AT mixed_result_table ASSIGNING FIELD-SYMBOL(<entry>).
      check_next_word( offset = <entry>-offset + <entry>-length
                       text_to_check = string_to_parse ).
      IF <entry>-is_link = abap_false AND decoded_abap_doc-default IS INITIAL.
        decoded_abap_doc-default = `"` && get_annotation_value( length = <entry>-length - 1
                                                                offset = <entry>-offset
                                                                to_decode = string_to_parse
                                                                length_of_annotation = 9
                                                                remove_whitespaces = abap_false ) && `"`.
      ELSEIF <entry>-is_link = abap_true AND decoded_abap_doc-default IS INITIAL.
        DATA(link) = get_annotation_value( length = <entry>-length - 1 offset = <entry>-offset to_decode = string_to_parse length_of_annotation = 9 remove_whitespaces = abap_true ).
        DATA(link_for_testing) = link.
        REPLACE ALL OCCURRENCES OF PCRE `\s` IN link_for_testing WITH ``.
        REPLACE ALL OCCURRENCES OF PCRE `(@link|data:)` IN link_for_testing WITH ``.
        SPLIT link_for_testing AT '.' INTO TABLE DATA(splitted).
        IF lines( splitted ) = 3.
          decoded_abap_doc-default = link.
        ELSEIF warning_set = abap_false.
          MESSAGE w111(saff_core) WITH abap_doc_annotation-default component_name INTO message ##NEEDED.
          parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
          warning_set = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_enum_values.
    IF decoded_abap_doc-enumvalues_link IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(string_to_parse) = abap_doc_string.
    REPLACE ALL OCCURRENCES OF PCRE `\$values[\s]*(:[\s]*)?\{[\s]*@link` IN string_to_parse WITH `\$values\{@link`.
    FIND ALL OCCURRENCES OF PCRE `\$values\{@link([^\}]+)\}` IN string_to_parse RESULTS DATA(result_table).
    IF lines( result_table ) = 0.
      MESSAGE w109(saff_core) WITH abap_doc_annotation-values component_name INTO DATA(message) ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
      RETURN.
    ENDIF.
    IF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH abap_doc_annotation-values component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(warning_written) = abap_false.
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      DATA(offset_found) = <entry>-offset.
      DATA(length_found) = <entry>-length.
      DATA(link) = get_annotation_value( length = length_found - 1
                                         offset = offset_found
                                         to_decode = string_to_parse
                                         length_of_annotation = 13
                                         remove_whitespaces = abap_true ).
      check_next_word( offset = offset_found + length_found
                       text_to_check = string_to_parse ).
      DATA(link_for_testing) = link.
      REPLACE ALL OCCURRENCES OF PCRE `\s` IN link_for_testing WITH ``.
      REPLACE ALL OCCURRENCES OF PCRE `data:` IN link_for_testing WITH ``.
      SPLIT link_for_testing AT '.' INTO TABLE DATA(splitted).
      IF lines( splitted ) = 2 AND decoded_abap_doc-enumvalues_link IS INITIAL.
        decoded_abap_doc-enumvalues_link = link.
      ELSEIF lines( splitted ) <> 2 AND warning_written = abap_false.
        MESSAGE w111(saff_core) WITH abap_doc_annotation-values component_name INTO message ##NEEDED.
        parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
        warning_written = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD parse_required.
    IF decoded_abap_doc-required IS NOT INITIAL.
      RETURN.
    ENDIF.
    FIND ALL OCCURRENCES OF abap_doc_annotation-required IN abap_doc_string RESULTS DATA(result_table).
    IF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH abap_doc_annotation-required component_name INTO DATA(message) ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    decoded_abap_doc-required = abap_true.
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      check_next_word( offset = <entry>-offset + <entry>-length
                       text_to_check = abap_doc_string ).
    ENDLOOP.
  ENDMETHOD.


  METHOD parse_show_always.
    IF decoded_abap_doc-showalways IS NOT INITIAL.
      RETURN.
    ENDIF.
    FIND ALL OCCURRENCES OF abap_doc_annotation-show_always IN abap_doc_string RESULTS DATA(result_table).
    IF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH abap_doc_annotation-show_always component_name INTO DATA(message) ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    decoded_abap_doc-showalways = abap_true.
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      check_next_word( offset = <entry>-offset + <entry>-length
                       text_to_check = abap_doc_string ).
    ENDLOOP.
  ENDMETHOD.


  METHOD parse_number_annotations.
    CASE key_word.
      WHEN abap_doc_annotation-minimum.
        IF decoded_abap_doc-minimum IS INITIAL.
          decoded_abap_doc-minimum = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-maximum.
        IF decoded_abap_doc-maximum IS INITIAL.
          decoded_abap_doc-maximum = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-exclusive_minimum.
        IF decoded_abap_doc-exclusive_minimum IS INITIAL.
          decoded_abap_doc-exclusive_minimum = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-exclusive_maximum.
        IF decoded_abap_doc-exclusive_maximum IS INITIAL.
          decoded_abap_doc-exclusive_maximum = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-multiple_of.
        IF decoded_abap_doc-multiple_of IS INITIAL.
          decoded_abap_doc-multiple_of = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-min_length.
        IF decoded_abap_doc-min_length IS INITIAL.
          decoded_abap_doc-min_length = get_number_annotation( annotation_name = key_word ).
        ENDIF.
      WHEN abap_doc_annotation-max_length.
        IF decoded_abap_doc-max_length IS INITIAL.
          decoded_abap_doc-max_length = get_number_annotation( annotation_name = key_word ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD get_number_annotation.
    DATA(abap_doc) = abap_doc_string.
    DATA(dummy_annotation) = `$dummyannotation`.
    REPLACE ALL OCCURRENCES OF annotation_name IN abap_doc WITH dummy_annotation.
    REPLACE ALL OCCURRENCES OF PCRE `\$dummyannotation[\s]*(:[\s]*)?` IN abap_doc WITH `\$dummyannotation`.
    FIND ALL OCCURRENCES OF PCRE `\$dummyannotation[^\s]+` IN abap_doc RESULTS DATA(result_table).
    IF lines( result_table ) = 0.
      MESSAGE w109(saff_core) WITH abap_doc_annotation-values component_name INTO DATA(message) ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
      RETURN.
    ENDIF.
    IF lines( result_table ) > 1.
      MESSAGE i107(saff_core) WITH annotation_name component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
    DATA(annotation_length) = strlen( dummy_annotation ).
    DATA(regex_of_number_expressions) = cl_abap_regex=>create_pcre( pattern     = `(\+|-)?[0-9]+(.[0-9]+)?(e(\+|-)?[0-9]+)?`
                                                                    ignore_case = abap_true ).
    DATA(warning_written) = abap_false.
    LOOP AT result_table ASSIGNING FIELD-SYMBOL(<entry>).
      DATA(offset_found) = <entry>-offset.
      DATA(length_found) = <entry>-length.
      DATA(begin_of_number) = offset_found + annotation_length.
      DATA(length_of_number) = length_found - annotation_length.
      DATA(number_candidate) = abap_doc+begin_of_number(length_of_number).
      remove_leading_trailing_spaces( CHANGING string_to_work_on = number_candidate ).
      DATA(matcher) = regex_of_number_expressions->create_matcher( text = number_candidate ).
      DATA(match) = matcher->match( ).
      check_next_word( offset = offset_found + length_found
                       text_to_check = abap_doc ).
      IF match = abap_true AND number IS INITIAL.
        number = number_candidate.
      ELSEIF match = abap_false AND warning_written = abap_false.
        MESSAGE w110(saff_core) WITH annotation_name component_name INTO message ##NEEDED.
        parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
        warning_written = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD remove_leading_trailing_spaces.
    SHIFT string_to_work_on RIGHT DELETING TRAILING space.
    SHIFT string_to_work_on LEFT DELETING LEADING space.
  ENDMETHOD.


  METHOD check_next_word.
    IF description_warning_is_needed = abap_true.
      RETURN.
    ENDIF.
    DATA(current_offset) = offset.
    DATA next_word TYPE string.
    DATA next_char TYPE c.

    WHILE next_char = space AND current_offset < strlen( text_to_check ).
      next_char = text_to_check+current_offset(1).
      current_offset += 1.
    ENDWHILE.
    next_word = next_char.
    IF current_offset >= strlen( text_to_check ).
      RETURN.
    ENDIF.
    DATA(regex_of_letter) = cl_abap_regex=>create_pcre( pattern = `[a-zA-Z]` ) ##NO_TEXT.
    DO.
      next_char = text_to_check+current_offset(1).
      current_offset += 1.
      next_word = next_word && next_char.
      IF regex_of_letter->create_matcher( text = next_char )->match( ) = abap_false OR current_offset >= strlen( text_to_check ).
        EXIT.
      ENDIF.
    ENDDO.
    remove_leading_trailing_spaces( CHANGING string_to_work_on = next_word ).
    IF strlen( next_word ) = 1 OR next_word+0(1) <> `$`.
      description_warning_is_needed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD write_description_message.
    IF description_warning_is_needed = abap_true AND decoded_abap_doc-description IS INITIAL.
      MESSAGE w115(saff_core) WITH component_name INTO DATA(message) ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( )
                               object = VALUE #( ) ).
    ELSEIF description_warning_is_needed = abap_true AND decoded_abap_doc-description IS NOT INITIAL.
      MESSAGE i116(saff_core) WITH component_name INTO message ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
  ENDMETHOD.


  METHOD check_redundant_annotations.
    IF decoded_abap_doc-showalways = abap_true AND decoded_abap_doc-required = abap_true.
      MESSAGE i112(saff_core) WITH component_name INTO DATA(message) ##NEEDED.
      parser_log->add_info( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.

    IF decoded_abap_doc-required = abap_true AND decoded_abap_doc-default IS NOT INITIAL.
      MESSAGE w126(saff_core) WITH component_name INTO message ##NEEDED.
      parser_log->add_warning( message = cl_aff_log=>get_sy_message( ) object = VALUE #( ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.