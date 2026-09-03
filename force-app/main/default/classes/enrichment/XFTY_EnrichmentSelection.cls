/**
 * Answers "does this config want the ancestor / child / inverse at this position?"
 * for `XFTY_BundleEnricher`'s recursive walk. Built once from the config.
 *
 * A path is keyed as a `>`-joined string of field names (built with `+=`, not
 * `String.join` - `join` is on the check-apex-style reserved list).
 */
@IsTest
public class XFTY_EnrichmentSelection {

    private final XFTY_InjectConfig config;
    private final Set<String> includedParentKeys = new Set<String>();
    private final Set<String> excludedParentKeys = new Set<String>();

    public XFTY_EnrichmentSelection(XFTY_InjectConfig config) {
        this.config = config;
        for (List<SObjectField> path : config.includedParentPaths) {
            this.includeWithPrefixes(path);
        }
        for (XFTY_InjectConfig.AncestorValue ancestorValue : config.ancestorValues) {
            this.includeWithPrefixes(ancestorValue.relationshipPrefix());
        }
        for (List<SObjectField> path : config.excludedParentPaths) {
            this.excludedParentKeys.add(keyOf(path));
        }
    }

    /**
     * `pathFromEntry` is the upward-hop path from the entry target to this
     * candidate ancestor - `null` once the walk has turned downward, so
     * `injectParent` never reaches into a child's ancestors.
     */
    public Boolean wantsAncestor(List<SObjectField> pathFromEntry) {
        if (pathFromEntry == null) {
            return this.config.fromAllParents;
        }
        if (this.hasExcludedPrefix(pathFromEntry)) {
            return false;
        }
        return this.config.fromAllParents || this.includedParentKeys.contains(keyOf(pathFromEntry));
    }

    /** Whether an ancestor generated for the level below should carry that level back as its child subquery. */
    public Boolean wantsInverse(SObjectField relationshipField) {
        return this.config.fromAllChildren && !this.config.excludedChildFields.contains(relationshipField);
    }

    /** The child relationship fields to inject at this position; `isRoot` gates the per-collection `injectChild(...)`. */
    public Set<SObjectField> childFieldsOn(XFTY_DummySObjectBundle subBundle, Boolean isRoot) {
        Set<SObjectField> present = materialised(subBundle.childRelationshipFields());
        Set<SObjectField> wanted = new Set<SObjectField>();
        if (this.config.fromAllChildren) {
            wanted.addAll(present);
        }
        if (isRoot) {
            wanted.addAll(this.namedChildFieldsPresentIn(present));
        }
        wanted.removeAll(this.config.excludedChildFields);
        return wanted;
    }

    private Set<SObjectField> namedChildFieldsPresentIn(Set<SObjectField> present) {
        Set<SObjectField> named = new Set<SObjectField>();
        for (SObjectField childField : this.config.includedChildFields) {
            if (present.contains(childField)) {
                named.add(childField);
            }
        }
        return named;
    }

    /** The `>`-joined key for a path; `''` for an empty or null path. */
    public static String keyOf(List<SObjectField> path) {
        if (path == null) {
            return '';
        }
        String key = '';
        for (SObjectField step : path) {
            key += step + '>';
        }
        return key;
    }

    private void includeWithPrefixes(List<SObjectField> path) {
        for (Integer length = 1; length <= path.size(); length++) {
            this.includedParentKeys.add(keyOf(prefixOf(path, length)));
        }
    }

    private Boolean hasExcludedPrefix(List<SObjectField> path) {
        for (Integer length = 1; length <= path.size(); length++) {
            if (this.excludedParentKeys.contains(keyOf(prefixOf(path, length)))) {
                return true;
            }
        }
        return false;
    }

    private static List<SObjectField> prefixOf(List<SObjectField> path, Integer length) {
        List<SObjectField> prefix = new List<SObjectField>();
        for (Integer i = 0; i < length; i++) {
            prefix.add(path[i]);
        }
        return prefix;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}
