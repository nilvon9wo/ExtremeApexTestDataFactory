/**
 * One `put(List<SObjectField> path, value)` on an `XFTY_DummySObjectProvider` -
 * a value (of any kind) targeted at a field on a **generated ancestor**, reached
 * by walking a path of relationship fields, for this call only.
 *
 * `path` is `[rel1, rel2, ..., targetField]`: every element but the last is a
 * relationship that is forced generated (same as `includeOptional`), and the
 * last is the field the value lands on. The value half is an
 * `XFTY_PathTargetValue`.
 *
 * Immutable. Threaded through `XFTY_GenerationContext`; `tail()` drops the head
 * as the engine recurses one relationship down.
 */
@IsTest
public class XFTY_PathValue {

    public final List<SObjectField> path;
    public final XFTY_PathTargetValue value;

    private XFTY_PathValue(List<SObjectField> path, XFTY_PathTargetValue value) {
        assertPath(path);
        this.path = path;
        this.value = value;
    }

    public static XFTY_PathValue ofExpression(List<SObjectField> path, XFTY_ValueExpressionIntf expression) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, XFTY_PathTargetValue.ofExpression(expression));
    }

    public static XFTY_PathValue ofContextAware(List<SObjectField> path, XFTY_ContextAwareExpressionIntf contextAware) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, XFTY_PathTargetValue.ofContextAware(contextAware));
    }

    public static XFTY_PathValue ofLiteral(List<SObjectField> path, Object literal) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, XFTY_PathTargetValue.ofLiteral(literal));
    }

    public static XFTY_PathValue ofRequiredRelationship(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf rel) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, XFTY_PathTargetValue.ofRequiredRelationship(rel));
    }

    public static XFTY_PathValue ofOptionalRelationship(List<SObjectField> path, XFTY_DummyDefaultRelationshipIntf rel) {
        assertUsablePath(path);
        return new XFTY_PathValue(path, XFTY_PathTargetValue.ofOptionalRelationship(rel));
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

    /** True when the value is itself a relationship (`putRequired`/`putOptional` path form). */
    public Boolean isRelationshipKind() {
        return this.value.isRelationship();
    }

    /** True when the value is a shared ancestor (`putRequired(path, XFTY_SharedAncestor.get(name))`). */
    public Boolean isSharedRelationshipValue() {
        return this.value.isSharedRelationship();
    }

    /** The same value, one relationship deeper (head dropped). Only valid when `!isAtTarget()`. */
    public XFTY_PathValue tail() {
        List<SObjectField> rest = new List<SObjectField>();
        for (Integer i = 1; i < this.path.size(); i++) {
            rest.add(this.path[i]);
        }
        return new XFTY_PathValue(rest, this.value);
    }

    /** Land the value on `template` (call only when `isAtTarget()`). */
    public void applyTo(XFTY_DummySObjectMasterTemplate template) {
        this.value.applyTo(template, this.path[0]);
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
