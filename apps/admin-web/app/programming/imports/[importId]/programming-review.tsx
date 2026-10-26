"use client";

import type {
  ImportedBlockDraft,
  ImportedMovementDraft,
  ProgrammingImportDraft,
} from "@oc-training-log/contracts";
import {
  PROGRAMMING_BLOCK_TYPES,
  PROGRAMMING_RESULT_SCHEMAS,
  programmingDraftBlockingIssues,
} from "@oc-training-log/domain";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

const blockLabels: Record<string, string> = {
  warm_up: "Warm-up",
  jumps: "Jumps",
  strength: "Strength",
  accessory: "Accessory",
  wod: "WOD",
  finisher: "Finisher",
  recovery: "Recovery",
  other: "Needs label",
};

const resultLabels: Record<string, string> = {
  weighted_fixed_reps: "Weight",
  weighted_variable_reps: "Weight + completed reps",
  height_or_distance: "Height or distance",
  for_time: "Time",
  max_repetitions: "Maximum reps",
  calories_or_distance: "Calories or distance",
  rounds_and_reps: "Rounds + reps",
  notes_only: "Unscored / notes only",
};

export function ProgrammingReview({
  importId,
  initialDraft,
  published,
  sourceLabel,
}: {
  importId: string;
  initialDraft: ProgrammingImportDraft;
  published: boolean;
  sourceLabel: string;
}) {
  const router = useRouter();
  const [draft, setDraft] = useState(initialDraft);
  const [activeDay, setActiveDay] = useState(0);
  const [view, setView] = useState<"review" | "preview">("review");
  const [busy, setBusy] = useState<"save" | "publish" | null>(null);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const issues = useMemo(() => programmingDraftBlockingIssues(draft), [draft]);
  const day = draft.days[activeDay] ?? draft.days[0]!;

  function change(mutator: (next: ProgrammingImportDraft) => void) {
    setDraft((current) => {
      const next = structuredClone(current);
      mutator(next);
      return next;
    });
    setNotice("");
    setError("");
  }

  async function save() {
    setBusy("save");
    setError("");
    const response = await fetch(`/api/admin/programming/imports/${importId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ draft }),
    });
    setBusy(null);
    if (!response.ok) {
      setError("The review draft could not be saved.");
      return;
    }
    setNotice("Draft saved.");
  }

  async function publish() {
    if (issues.length) {
      setError("Resolve the review items before publishing.");
      return;
    }
    if (
      !window.confirm(
        `Publish ${draft.days.length} ${draft.trackCode} programming ${draft.days.length === 1 ? "day" : "days"} to members?`,
      )
    )
      return;
    setBusy("publish");
    setError("");
    const response = await fetch(
      `/api/admin/programming/imports/${importId}/publish`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ draft }),
      },
    );
    const body = (await response.json()) as {
      publishedCount?: number;
      issues?: string[];
    };
    setBusy(null);
    if (!response.ok) {
      setError(
        body.issues?.[0] ??
          "Publication failed. Reopen the draft and try again.",
      );
      return;
    }
    router.push(
      `/programming?published=${body.publishedCount ?? draft.days.length}`,
    );
    router.refresh();
  }

  if (published) {
    return (
      <section className="panel published-panel">
        <p className="success-banner">This import has been published.</p>
        <p>
          The member-facing programming is retained as a separate published
          version so this source review cannot accidentally rewrite workout
          history.
        </p>
      </section>
    );
  }

  return (
    <>
      <section
        className="review-toolbar"
        aria-label="Programming review controls"
      >
        <div>
          <strong>{draft.trackCode}</strong>
          <span>
            {draft.days.length} parsed{" "}
            {draft.days.length === 1 ? "day" : "days"} · {sourceLabel}
          </span>
        </div>
        <div className="view-switch">
          <button
            className={view === "review" ? "active" : ""}
            onClick={() => setView("review")}
            type="button"
          >
            Review source
          </button>
          <button
            className={view === "preview" ? "active" : ""}
            onClick={() => setView("preview")}
            type="button"
          >
            Member preview
          </button>
        </div>
      </section>

      <nav className="day-tabs" aria-label="Imported dates">
        {draft.days.map((item, index) => {
          const hasIssue =
            programmingDraftBlockingIssues({
              ...draft,
              warnings: [],
              days: [item],
            }).length > 0;
          return (
            <button
              className={activeDay === index ? "active" : ""}
              key={item.id}
              onClick={() => setActiveDay(index)}
              type="button"
            >
              <span>{formatDate(item.workoutDate)}</span>
              <small>{hasIssue ? "Review needed" : "Ready"}</small>
            </button>
          );
        })}
      </nav>

      {draft.warnings.length ? (
        <section className="warning-banner">
          <div>
            <strong>Source review needed</strong>
            {draft.warnings.map((warning) => (
              <p key={warning}>{warning}</p>
            ))}
          </div>
          <button
            type="button"
            onClick={() =>
              change((next) => {
                next.warnings = [];
              })
            }
          >
            I reviewed this
          </button>
        </section>
      ) : null}

      {view === "preview" ? (
        <MemberPreview day={day} trackCode={draft.trackCode} />
      ) : (
        <div className="source-review-grid">
          <aside className="source-panel">
            <div>
              <p className="eyebrow">Original source</p>
              <h2>{formatDate(day.workoutDate)}</h2>
            </div>
            <pre>{day.sourceExcerpt}</pre>
          </aside>
          <section className="review-editor">
            <div className="editor-heading">
              <div>
                <p className="eyebrow">Member-facing structure</p>
                <h2>Edit this day</h2>
              </div>
              <span className={`confidence confidence-${day.confidence}`}>
                {day.confidence} confidence
              </span>
            </div>
            {day.warnings.length ? (
              <div className="inline-warning">
                {day.warnings.map((warning) => (
                  <p key={warning}>{warning}</p>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    change((next) => {
                      next.days[activeDay]!.warnings = [];
                    })
                  }
                >
                  I resolved this
                </button>
              </div>
            ) : null}
            <div className="form-grid two-column-form">
              <label>
                Workout date
                <input
                  type="date"
                  value={day.workoutDate}
                  onChange={(event) =>
                    change((next) => {
                      next.days[activeDay]!.workoutDate = event.target.value;
                    })
                  }
                />
              </label>
              <label>
                Workout title
                <input
                  value={day.title}
                  onChange={(event) =>
                    change((next) => {
                      next.days[activeDay]!.title = event.target.value;
                    })
                  }
                />
              </label>
            </div>
            <label className="stacked-label compact-label">
              <span>
                <input
                  type="checkbox"
                  checked={day.isClosed ?? false}
                  onChange={(event) =>
                    change((next) => {
                      const target = next.days[activeDay]!;
                      target.isClosed = event.target.checked;
                      if (target.isClosed) {
                        target.title = "Gym Closed";
                        target.blocks = [];
                        target.warnings = [];
                      } else if (target.blocks.length === 0) {
                        target.blocks = [newBlock()];
                      }
                    })
                  }
                />{" "}
                Gym Closed — visible to members and cannot be logged
              </span>
            </label>
            <label className="stacked-label">
              Coach notes
              <textarea
                rows={2}
                value={day.coachNotes}
                onChange={(event) =>
                  change((next) => {
                    next.days[activeDay]!.coachNotes = event.target.value;
                  })
                }
              />
            </label>

            {!day.isClosed ? (
              <>
                <div className="block-editor-list">
                  {day.blocks.map((block, blockIndex) => (
                    <BlockEditor
                      block={block}
                      canRemove={day.blocks.length > 1}
                      key={block.id}
                      onChange={(mutator) =>
                        change((next) =>
                          mutator(next.days[activeDay]!.blocks[blockIndex]!),
                        )
                      }
                      onRemove={() =>
                        change((next) => {
                          next.days[activeDay]!.blocks.splice(blockIndex, 1);
                        })
                      }
                    />
                  ))}
                </div>
                <button
                  className="add-row-button"
                  type="button"
                  onClick={() =>
                    change((next) => {
                      next.days[activeDay]!.blocks.push(newBlock());
                    })
                  }
                >
                  + Add block
                </button>
              </>
            ) : null}
          </section>
        </div>
      )}

      <section className="publish-bar">
        <div>
          {error ? (
            <p className="form-error" role="alert">
              {error}
            </p>
          ) : notice ? (
            <p className="save-notice" role="status">
              {notice}
            </p>
          ) : issues.length ? (
            <p>
              <strong>
                {issues.length} review {issues.length === 1 ? "item" : "items"}{" "}
                remaining.
              </strong>{" "}
              Confirm every uncertain item and clear warnings.
            </p>
          ) : (
            <p>
              <strong>Ready to publish.</strong> Preview the member view, then
              publish deliberately.
            </p>
          )}
        </div>
        <div className="form-actions">
          <button
            className="secondary-button"
            disabled={busy !== null}
            onClick={save}
            type="button"
          >
            {busy === "save" ? "Saving…" : "Save draft"}
          </button>
          <button
            className="primary-button"
            disabled={busy !== null || issues.length > 0}
            onClick={publish}
            type="button"
          >
            {busy === "publish"
              ? "Publishing…"
              : `Publish ${draft.days.length} ${draft.days.length === 1 ? "day" : "days"}`}
          </button>
        </div>
      </section>
    </>
  );
}

function BlockEditor({
  block,
  canRemove,
  onChange,
  onRemove,
}: {
  block: ImportedBlockDraft;
  canRemove: boolean;
  onChange(mutator: (block: ImportedBlockDraft) => void): void;
  onRemove(): void;
}) {
  return (
    <article className="block-editor">
      <div className="block-editor-heading">
        <select
          aria-label="Block type"
          value={block.type}
          onChange={(event) =>
            onChange((next) => {
              next.type = event.target.value as ImportedBlockDraft["type"];
              next.title = blockLabels[next.type]!;
              next.warnings =
                next.type === "other"
                  ? ["Choose the correct block label before publishing."]
                  : [];
              if (next.type === "warm_up" || next.type === "recovery")
                next.movements.forEach((movement) => {
                  movement.resultSchema = "notes_only";
                  movement.requiresReview = false;
                  movement.warnings = [];
                });
            })
          }
        >
          {PROGRAMMING_BLOCK_TYPES.map((type) => (
            <option key={type} value={type}>
              {blockLabels[type]}
            </option>
          ))}
        </select>
        <input
          aria-label="Block title"
          value={block.title}
          onChange={(event) =>
            onChange((next) => {
              next.title = event.target.value;
            })
          }
        />
        <button
          className="danger-text-button"
          disabled={!canRemove}
          onClick={onRemove}
          type="button"
        >
          Remove block
        </button>
      </div>
      {block.warnings.map((warning) => (
        <p className="field-warning" key={warning}>
          {warning}
        </p>
      ))}
      <label className="stacked-label compact-label">
        Block instructions
        <textarea
          rows={2}
          value={block.instructions}
          onChange={(event) =>
            onChange((next) => {
              next.instructions = event.target.value;
            })
          }
        />
      </label>
      <div className="movement-editor-list">
        {block.movements.map((movement, movementIndex) => (
          <MovementEditor
            key={movement.id}
            movement={movement}
            readOnlyBlock={
              block.type === "warm_up" || block.type === "recovery"
            }
            canRemove={block.movements.length > 1}
            onChange={(mutator) =>
              onChange((next) => mutator(next.movements[movementIndex]!))
            }
            onRemove={() =>
              onChange((next) => {
                next.movements.splice(movementIndex, 1);
              })
            }
          />
        ))}
      </div>
      <button
        className="add-row-button small"
        type="button"
        onClick={() =>
          onChange((next) => {
            next.movements.push(newMovement(next.type));
          })
        }
      >
        + Add item
      </button>
    </article>
  );
}

function MovementEditor({
  movement,
  readOnlyBlock,
  canRemove,
  onChange,
  onRemove,
}: {
  movement: ImportedMovementDraft;
  readOnlyBlock: boolean;
  canRemove: boolean;
  onChange(mutator: (movement: ImportedMovementDraft) => void): void;
  onRemove(): void;
}) {
  return (
    <div
      className={`movement-editor ${movement.requiresReview ? "needs-review" : ""}`}
    >
      <div className="movement-fields">
        <label>
          Item name
          <input
            value={movement.displayName}
            onChange={(event) =>
              onChange((next) => {
                next.displayName = event.target.value;
              })
            }
          />
        </label>
        <label>
          Member result input
          <select
            disabled={readOnlyBlock}
            value={movement.resultSchema}
            onChange={(event) =>
              onChange((next) => {
                next.resultSchema = event.target
                  .value as ImportedMovementDraft["resultSchema"];
                if (next.resultSchema === "notes_only") {
                  next.optionGroupKey = null;
                  next.optionGroupLabel = null;
                }
                next.requiresReview = false;
                next.warnings = [];
              })
            }
          >
            {PROGRAMMING_RESULT_SCHEMAS.map((schema) => (
              <option key={schema} value={schema}>
                {resultLabels[schema]}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="stacked-label compact-label">
        Prescription
        <textarea
          rows={3}
          value={movement.prescriptionText}
          onChange={(event) =>
            onChange((next) => {
              next.prescriptionText = event.target.value;
            })
          }
        />
      </label>
      <label className="stacked-label compact-label">
        Item notes
        <textarea
          rows={2}
          value={movement.coachNotes}
          onChange={(event) =>
            onChange((next) => {
              next.coachNotes = event.target.value;
            })
          }
        />
      </label>
      {!readOnlyBlock && movement.resultSchema !== "notes_only" ? (
        <div className="option-group-editor">
          <label>
            <input
              type="checkbox"
              checked={movement.optionGroupKey != null}
              onChange={(event) =>
                onChange((next) => {
                  next.optionGroupKey = event.target.checked
                    ? "workout-options"
                    : null;
                  next.optionGroupLabel = event.target.checked
                    ? "Select each option completed"
                    : null;
                })
              }
            />{" "}
            This item is a selectable workout option
          </label>
          {movement.optionGroupKey != null ? (
            <div className="movement-grid">
              <label>
                Group key
                <input
                  value={movement.optionGroupKey}
                  onChange={(event) =>
                    onChange((next) => {
                      next.optionGroupKey = event.target.value;
                    })
                  }
                />
              </label>
              <label>
                Member prompt
                <input
                  value={movement.optionGroupLabel ?? ""}
                  onChange={(event) =>
                    onChange((next) => {
                      next.optionGroupLabel = event.target.value;
                    })
                  }
                />
              </label>
            </div>
          ) : null}
        </div>
      ) : null}
      {movement.warnings.map((warning) => (
        <p className="field-warning" key={warning}>
          {warning}
        </p>
      ))}
      <div className="movement-actions">
        {movement.requiresReview ? (
          <button
            className="confirm-button"
            type="button"
            onClick={() =>
              onChange((next) => {
                next.requiresReview = false;
                next.warnings = [];
              })
            }
          >
            Confirm “{resultLabels[movement.resultSchema]}”
          </button>
        ) : (
          <span className="confirmed-label">Confirmed</span>
        )}
        <button
          className="danger-text-button"
          disabled={!canRemove}
          type="button"
          onClick={onRemove}
        >
          Remove item
        </button>
      </div>
    </div>
  );
}

function MemberPreview({
  day,
  trackCode,
}: {
  day: ProgrammingImportDraft["days"][number];
  trackCode: string;
}) {
  return (
    <section className="member-preview-wrap">
      <div className="phone-preview">
        <header>
          <span>OC TRAINING LOG</span>
          <b>{trackCode}</b>
        </header>
        <p className="preview-date">{formatDate(day.workoutDate)}</p>
        <h2>{day.title}</h2>
        {day.isClosed ? (
          <p className="preview-notes">
            The gym is closed. This day cannot be logged.
          </p>
        ) : null}
        {day.coachNotes ? (
          <p className="preview-notes">{day.coachNotes}</p>
        ) : null}
        {!day.isClosed ? (
          <div className="preview-blocks">
            {day.blocks.map((block) => (
              <section key={block.id}>
                <h3>{block.title}</h3>
                {block.instructions ? <p>{block.instructions}</p> : null}
                {block.movements.map((movement) => (
                  <article key={movement.id}>
                    <strong>{movement.displayName}</strong>
                    <p>{movement.prescriptionText}</p>
                    {movement.coachNotes ? (
                      <small>{movement.coachNotes}</small>
                    ) : null}
                    {movement.resultSchema !== "notes_only" ? (
                      <span className="input-preview">
                        {movement.optionGroupKey ? "Selectable · " : ""}Member
                        enters: {resultLabels[movement.resultSchema]}
                      </span>
                    ) : null}
                  </article>
                ))}
              </section>
            ))}
          </div>
        ) : null}
      </div>
    </section>
  );
}

function newBlock(): ImportedBlockDraft {
  return {
    id: crypto.randomUUID(),
    type: "other",
    title: "Other",
    instructions: "",
    confidence: "low",
    warnings: ["Choose the correct block label before publishing."],
    movements: [newMovement("other")],
  };
}

function newMovement(
  blockType: ImportedBlockDraft["type"],
): ImportedMovementDraft {
  const readOnly = blockType === "warm_up" || blockType === "recovery";
  return {
    id: crypto.randomUUID(),
    displayName: "",
    prescriptionText: "",
    coachNotes: "",
    optionGroupKey: null,
    optionGroupLabel: null,
    resultSchema: "notes_only",
    confidence: "low",
    requiresReview: !readOnly,
    warnings: readOnly ? [] : ["Confirm how members record this item."],
  };
}

function formatDate(date: string) {
  const parsed = new Date(`${date}T12:00:00Z`);
  return Number.isNaN(parsed.valueOf())
    ? date
    : new Intl.DateTimeFormat("en-US", {
        weekday: "short",
        month: "short",
        day: "numeric",
        year: "numeric",
        timeZone: "UTC",
      }).format(parsed);
}
