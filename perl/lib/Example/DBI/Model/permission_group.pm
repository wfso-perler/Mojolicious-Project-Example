package Example::DBI::Model::permission_group;
use strict;
use warnings;
use Example::DBI::Model -base;
use utf8;

has columns => sub{
    [
      "group_id", "group_status", "group_name", "group_intro",
      "create_type", "update_type", "create_time", "update_time"
    ]
  };

has ctime => "create_time";
has mtime => "update_time";
has primary_key => "group_id";


1;