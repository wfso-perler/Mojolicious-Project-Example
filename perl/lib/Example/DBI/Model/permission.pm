package Example::DBI::Model::permission;
use strict;
use warnings;
use Example::DBI::Model -base;
use utf8;

has columns => sub{
    [
      "permission_code", "group_id", "permission_status", "permission_name", "permission_intro",
      "create_type", "update_type", "create_time", "update_time"
    ]
  };

has ctime => "create_time";
has mtime => "update_time";
has primary_key => sub{["permission_code"]};


1;