/**
 * Applies the `put(List<SObjectField> path, value)` overrides that have reached
 * their target - `isAtTarget()` - by landing each value on a copy of the master
 * template for the level being generated. The relationship walk that got here is
 * handled by {@link XFTY_RelationshipForcer} (the prefixes are folded into the
 * forced-relationship paths).
 */
@IsTest
public class XFTY_PathValueApplier {

    public static XFTY_DummySObjectMasterTemplate apply(
            List<XFTY_PathValue> pathValues,
            XFTY_DummySObjectMasterTemplate template
    ) {
        List<XFTY_PathValue> atTarget = new List<XFTY_PathValue>();
        for (XFTY_PathValue pathValue : pathValues) {
            if (pathValue.isAtTarget()) {
                atTarget.add(pathValue);
            }
        }
        if (atTarget.isEmpty()) {
            return template;
        }
        XFTY_DummySObjectMasterTemplate overlaid = template.copy();
        for (XFTY_PathValue pathValue : atTarget) {
            pathValue.applyTo(overlaid);
        }
        return overlaid;
    }
}
