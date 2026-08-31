/**
 * One `put(List<SObjectField> path, value)` on an `XFTY_DummySObjectProvider` -
 * a value (of any kind) targeted at a field on a **generated ancestor**, reached
 * by walking a path of relationship fields, for this call only.
 *
 * `path` is `[rel1, rel2, ..., targetField]`: every element but the last is a
 * relationship that is forced generated (same as `includeOptional`), and the
 * last is the field the value lands on.
 *
 * Immutable. Threaded through `XFTY_GenerationContext`; `tail()` drops the head
 * as the engine recurses one relationship down.
 */
@IsTest
public class XFTY_PathValue {

    public enum Kind { VALUE_STRATEGY, CONTEXT_AWARE, LITERAL, REQUIRED_RELATIONSHIP, OPTIONAL_RELATIONSHIP }

    public final List<SObjectField> path;
    public final Kind kind;
    private final XFTY_DummyDefaultValueIntf valueStrategy;
    private final XFTY_ContextAwareValueIntf contextAwareValue;
    private final Object literal;
    private final XFTY_DummyDefaultRelationshipIntf relationship;

    private XFTY_PathValue(
            List<SObjectField> path,
            Kind kind,
            XFTY_DummyDefaultValueIntf valueStrategy,
            XFTY_ContextAwareValueIntf contextAwareValue,
            Object literal,
            XFTY_DummyDefaultRelationshipIntf relationship
    ) {
        assertPath(path);
        this.path = path;
        this.kind = kind;
        this.valueStrategy = valueStrategy;
        this.contextAwareValue = contextAwareValue;
        this.literal = literal;
        this.relationship = relationship;
    }

    public static XFTY_PathValue ofStrategy(List<SObjectField> path, XFTY_DummyDefaultValueIntf strategy) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, Kind.VALUE_STRATEGY, strategy, null, null, null);
    }
    public static XFTY_PathValue ofContextAware(List<SObjectField> path, XFTY_ContextAwareValueIntf contextAware) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, Kind.CONTEXT_AWARE, null, contextAware, null, null);
    }
    public static XFTY_PathValue ofLiteral(List<SObjectField> path, Object literal) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, Kind.LITERAL, null, null, literal, null);
    }
    public static XFTY_PathValue ofRequiredRelationship(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf rel) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, Kind.REQUIRED_RELATIONSHIP, null, null, null, rel);
    }
    public static XFTY_PathValue ofOptionalRelationship(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf rel) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, Kind.OPTIONAL_RELATIONSHIP, null, null, null, rel);
    }

    /** The path of relationship fields that must be forced generated to reach the target (path minus the target). */
    public List<SObjectField> relationshipPrefix() {
        List<SObjectField> prefix = new List<SObjectField>();
        for (Integer i = 0; i < this.path.size() - 1; i++) {
            prefix.add(this.path[i]);
        }
        return prefix;
    }

    public SObjectField head() {
        return this.path[0];
    }

    /** True when only the target field is left - this ancestor level is where the value lands. */
    public Boolean isAtTarget() {
        return this.path.size() == 1;
    }

    /** The same value, one relationship deeper (head dropped). Only valid when `!isAtTarget()`. */
    public XFTY_PathValue tail() {
        List<SObjectField> rest = new List<SObjectField>();
        for (Integer i = 1; i < this.path.size(); i++) {
            rest.add(this.path[i]);
        }
        return new XFTY_PathValue(rest, this.kind, this.valueStrategy, this.contextAwareValue, this.literal, this.relationship);
    }

    /** Land the value on `template` (call only when `isAtTarget()`). */
    public void applyTo(XFTY_DummySObjectMasterTemplate template) {
        SObjectField targetField = this.path[0];
        template.remove(targetField);
        switch on this.kind {
            when VALUE_STRATEGY {
                template.put(targetField, this.valueStrategy);
            }
            when CONTEXT_AWARE {
                template.put(targetField, this.contextAwareValue);
            }
            when LITERAL {
                template.put(targetField, this.literal);
            }
            when REQUIRED_RELATIONSHIP {
                template.putRequired(targetField, this.relationship);
            }
            when OPTIONAL_RELATIONSHIP {
                template.putOptional(targetField, this.relationship);
            }
        }
    }

    private static void assertPath(List<SObjectField> path) {
        if (path == null || path.isEmpty()) {
            throw new XFTY_DummySObjectFtyProviderException('A path value cannot have an empty path.');
        }
        for (SObjectField step : path) {
            if (step == null) {
                throw new XFTY_DummySObjectFtyProviderException('A path value cannot contain a null field.');
            }
        }
    }

    /** The public `put(path, ...)` entry points need a relationship step plus a target. */
    private static void assertUsablePath(List<SObjectField> path) {
        if (path == null || path.size() < 2) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'A path value needs at least one relationship field plus the target field '
                            + '- use plain put(field, value) for a field on the record itself.'
            );
        }
    }
}
