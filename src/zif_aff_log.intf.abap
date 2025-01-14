"! Log for the Schema/Simple Transformation writers.
INTERFACE zif_aff_log
  PUBLIC.

  CONSTANTS:
    BEGIN OF c_message_type,
      error   TYPE symsgty VALUE 'E',
      warning TYPE symsgty VALUE 'W',
      info    TYPE symsgty VALUE 'I',
    END OF c_message_type.

  TYPES:
    "! A single message entry in the log
    BEGIN OF ty_log_out,
      "! The name of the component for which the message was logged
      component_name TYPE string,
      "! The type of the message
      type           TYPE symsgty,
      "! The text of the message
      text           TYPE string,
      "! The message
      message        TYPE symsg,
    END OF ty_log_out,
    tt_log_out TYPE STANDARD TABLE OF ty_log_out WITH NON-UNIQUE DEFAULT KEY.

  METHODS:
    "! Adds an info message (type I) to the log.
    "!
    "! @parameter message | the message
    "! @parameter component_name | the name of the element for which the log entry is created
    add_info
      IMPORTING message        TYPE symsg
                component_name TYPE string,

    "! Adds a warning message (type W) to the log.
    "!
    "! @parameter message | the message
    "! @parameter component_name | the name of the element for which the log entry is created
    add_warning
      IMPORTING message        TYPE symsg
                component_name TYPE string,

    "! Adds an error message (type E) to the log.
    "!
    "! @parameter message | the message
    "! @parameter component_name | the name of the element for which the log entry is created
    add_error
      IMPORTING message        TYPE symsg
                component_name TYPE string,

    "! Adds an exception to the log. Actually not the exception is added
    "! but the message of the exception. The message type can be submitted.
    "!
    "! @parameter exception | the exception containing the message
    "! @parameter message_type | the type of the message
    "! @parameter component_name | the name of the element for which the log entry is created
    add_exception
      IMPORTING exception      TYPE REF TO cx_root
                message_type   TYPE symsgty DEFAULT c_message_type-error
                component_name TYPE string,

    "! Returns the logged messages. The log is NOT cleared afterwards.
    "! The caller has to {@link METH.clear} it in case it should be reused.
    "!
    "! @parameter messages | the logged messages
    get_messages
      RETURNING VALUE(messages) TYPE tt_log_out,

    "! Join the messages of another log with this log. Afterwards this log contains
    "! the messages of the other log.
    "!
    "! @parameter log_to_join | the other log
    join
      IMPORTING log_to_join TYPE REF TO zif_aff_log,

    "! Clears all messages of this log.
    "!
    clear,

    "! Calculates the maximum severity of the logged messages.
    "! This is (in order):
    "! E - Error
    "! W - Warning
    "! I - Information
    "!
    "! @parameter max_severity | the maximum severity of the logged messages
    get_max_severity
      RETURNING VALUE(max_severity) TYPE symsgty,

    "! Returns true if the log contains messages, false otherwise.
    "!
    "! @parameter has_messages | true or false
    has_messages
      RETURNING VALUE(has_messages) TYPE abap_bool.

ENDINTERFACE.
