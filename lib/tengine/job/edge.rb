# -*- coding: utf-8 -*-
require 'tengine/job'
require 'selectable_attr'

# Vertexとともにジョブネットを構成するグラフの「辺」を表すモデル
# Tengine::Job::Jobnetにembeddedされます。
class Tengine::Job::Edge
  include SelectableAttr::Base
  include Mongoid::Document

  embedded_in :owner, :class_name => "Tengine::Job::Jobnet", :inverse_of => :edges

  field :status_cd     , :type => Integer        # ステータス。とりうる値は後述を参照してください。詳しくはtengine_jobパッケージ設計書の「edge状態遷移」を参照してください。
  field :origin_id     , :type => BSON::ObjectId # 辺の遷移元となるvertexのid
  field :destination_id, :type => BSON::ObjectId # 辺の遷移先となるvertexのid

  selectable_attr :status_cd do
    entry  0, :active      , "active"
    entry 10, :transmitting, "transmitting"
    entry 20, :transmitted , "transmitted"
    entry 30, :suspended   , "suspended"
    entry 31, :keeping     , "keeping"
  end

  def origin
    owner.children.detect{|c| c.id == origin_id}
  end

  def destination
    owner.children.detect{|c| c.id == destination_id}
  end
end
