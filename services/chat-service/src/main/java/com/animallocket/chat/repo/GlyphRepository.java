package com.animallocket.chat.repo;

import com.animallocket.chat.domain.ConversationGlyph;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface GlyphRepository extends MongoRepository<ConversationGlyph, String> {
    Optional<ConversationGlyph> findFirstByConversationIdOrderByRevisionDesc(String conversationId);

    List<ConversationGlyph> findByConversationIdAndRevisionGreaterThanAndRevisionLessThanEqualOrderByRevisionAsc(
            String conversationId, long afterRevision, long upToRevision, Pageable page);

    Optional<ConversationGlyph> findByConversationIdAndCreatorPublicIdAndClientMutationId(
            String conversationId, String creatorPublicId, String clientMutationId);

    boolean existsByConversationIdAndShapeHashAndStatus(String conversationId, String shapeHash,
                                                        ConversationGlyph.Status status);

    long countByConversationIdAndStatus(String conversationId, ConversationGlyph.Status status);

    List<ConversationGlyph> findByConversationIdAndIdIn(String conversationId, Collection<String> ids);

    void deleteByConversationId(String conversationId);
}
