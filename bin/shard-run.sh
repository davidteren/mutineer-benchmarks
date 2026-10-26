#!/bin/bash
i=$1; cd /workspace/fizzy-shard$i; export RAILS_ENV=test
TESTS=$(find test/models -name '*_test.rb' | sort | sed 's/^/--test /')
s=$(date +%s.%N); echo "start $(date)"
bundle exec mutineer run $(cat /workspace/shard$i.files) $TESTS --rails --strategy redefine --operators arithmetic,comparison,boolean_connector,boolean_literal,statement_removal,return_nil,literal_mutation,condition_negation,string_literal,regex,collection_method,safe_navigation,range,negation_removal,chain_link,call_to_receiver,operand_removal,array_literal,condition_true,condition_false,operator_assignment --format json --output /workspace/shard$i.json
echo "exit=$? wall=$(ruby -e "puts (Time.now.to_f - $s).round(1)") end $(date)"
