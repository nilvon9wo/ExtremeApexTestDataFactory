/**
 * The value half of an `XFTY_PathValue` - what lands on the field a `put(path,
 * ...)` targets, in one of five kinds. Built through a named factory so the kinds
 * never turn into positional-argument soup, and immutable once built.
 */
@IsTest
public class XFTY_PathTargetValue {

    public enum Kind { VALUE_EXPRESSION, CONTEXT_AWARE, LITERAL, REQUIRED_RELATIONSHIP, OPTIONAL_RELATIONSHIP }

    public final Kind valueKind;
    private final Object payload;

    private XFTY_PathTargetValue(Kind kind, Object payload) {
        this.valueKind = kind;
        this.payload = payload;
    }

    public static XFTY_PathTargetValue ofExpression(XFTY_ValueExpressionIntf expression) {
        return new XFTY_PathTargetValue(Kind.VALUE_EXPRESSION, expression);
    }

    public static XFTY_PathTargetValue ofContextAware(XFTY_ContextAwareExpressionIntf contextAware) {
        return new XFTY_PathTargetValue(Kind.CONTEXT_AWARE, contextAware);
    }

    public static XFTY_PathTargetValue ofLiteral(Object literal) {
        return new XFTY_PathTargetValue(Kind.LITERAL, literal);
    }

    public static XFTY_PathTargetValue ofRequiredRelationship(XFTY_DummyDefaultRelationshipIntf relationship) {
        return new XFTY_PathTargetValue(Kind.REQUIRED_RELATIONSHIP, relationship);
    }

    public static XFTY_PathTargetValue ofOptionalRelationship(XFTY_DummyDefaultRelationshipIntf relationship) {
        return new XFTY_PathTargetValue(Kind.OPTIONAL_RELATIONSHIP, relationship);
    }

    public Boolean isRelationship() {
        return this.valueKind == Kind.REQUIRED_RELATIONSHIP || this.valueKind == Kind.OPTIONAL_RELATIONSHIP;
    }

    /** True when the value is a shared ancestor (`putRequired(path, XFTY_SharedAncestor.get(name))`). */
    public Boolean isSharedRelationship() {
        return this.payload instanceof XFTY_SharedRelationshipIntf;
    }

    /** Land the value on `template.targetField` for the ancestor level being generated. */
    public void applyTo(XFTY_DummySObjectMasterTemplate template, SObjectField targetField) {
        template.remove(targetField);
        switch on this.valueKind {
            when VALUE_EXPRESSION {
                template.put(targetField, (XFTY_ValueExpressionIntf) this.payload);
            }
            when CONTEXT_AWARE {
                template.put(targetField, (XFTY_ContextAwareExpressionIntf) this.payload);
            }
            when LITERAL {
                template.put(targetField, this.payload);
            }
            when REQUIRED_RELATIONSHIP {
                template.putRequired(targetField, (XFTY_DummyDefaultRelationshipIntf) this.payload);
            }
            when OPTIONAL_RELATIONSHIP {
                template.putOptional(targetField, (XFTY_DummyDefaultRelationshipIntf) this.payload);
            }
        }
    }

}
