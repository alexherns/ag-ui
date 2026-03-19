"""
A simple agentic chat flow using LangGraph with proper streaming and reasoning.
"""

import os
from typing import Any, Dict, AsyncIterator

from langchain_core.messages import SystemMessage
from langchain_core.runnables import RunnableConfig
from langchain_google_vertexai import ChatVertexAI
from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, MessagesState, StateGraph
from langgraph.types import Command

async def chat_node(state: Dict[str, Any], config: RunnableConfig):
    model = ChatVertexAI(
        model="gemini-2.5-flash",
        project=os.getenv("GCP_PROJECT"),
        location=os.getenv("GCP_REGION", "us-central1"),
        streaming=True,
        include_thoughts=True,
    )
    # Run the model with streaming enabled (astream_events handles this)
    response = await model.ainvoke(
        [SystemMessage(content="You are a helpful assistant."), *state["messages"]],
        config,
    )

    # Update messages with the response
    messages = state["messages"] + [response]

    return Command(goto=END, update={"messages": messages})


# Define the graph
workflow = StateGraph(MessagesState)
workflow.add_node("chat_node", chat_node)
workflow.set_entry_point("chat_node")
workflow.add_edge("chat_node", END)

memory = MemorySaver()
graph = workflow.compile(checkpointer=memory)
