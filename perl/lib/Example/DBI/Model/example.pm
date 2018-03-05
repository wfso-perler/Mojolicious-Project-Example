package Example::DBI::Model::example;
use Example::DBI::Model -base;
use strict;
use warnings;
use utf8;

has columns => sub{
    [
      "example_id", "example_name", "example_intro", "create_time", "update_time", "is_deleted"
    ]
  };

has ctime => "create_time";
has mtime => "update_time";
has primary_key => "example_id";


1;