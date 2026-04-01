# Enrichable - 数据增强
# 学习自 Sure

module Enrichable
  extend ActiveSupport::Concern
  
  included do
    has_many :enrichments, as: :enrichable, class_name: '::DataEnrichment', dependent: :destroy
    
    def enrich(attribute_name, value, source: 'unknown', metadata: {})
      enrichments.create!(
        attribute_name: attribute_name,
        value: value,
        source: source,
        metadata: metadata
      )
    end
    
    def enrichment_for(attribute_name)
      enrichments.where(attribute_name: attribute_name).order(created_at: :desc).first
    end
    
    def clear_ai_cache
      # 清除 AI 生成的缓存数据
      enrichments.where(source: 'ai').destroy_all
    end
  end
end